# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "time"

require_relative "errors"
require_relative "object"
require_relative "version"

module NeonAPI
  # The low-level HTTP layer. Wraps Net::HTTP with bearer-token authentication,
  # JSON encoding/decoding, sane timeouts, and structured error handling.
  #
  # You normally don't construct this directly — {NeonAPI::Client} owns a
  # Connection and exposes higher-level methods. It's public so advanced callers
  # can hit endpoints this gem hasn't wrapped yet:
  #
  #   client.connection.get("projects/#{id}/some/new/endpoint")
  #
  # Relies only on the Ruby standard library; no third-party HTTP dependency.
  class Connection
    # The default Neon API base URL (note the trailing slash and /api/v2/ path).
    DEFAULT_BASE_URL = "https://console.neon.tech/api/v2/"

    # HTTP methods safe to retry on transient 5xx / network errors. (429 is
    # retried for every method, since a rate-limited request was never processed.)
    IDEMPOTENT_METHODS = %i[get put delete head options].freeze

    # No-op instrumenter. Pass `ActiveSupport::Notifications` (or any object with
    # a compatible `#instrument(name, payload) { ... }`) to observe requests;
    # subscribe to the `"request.neon_api"` event for method/path/status/attempts.
    module NullInstrumenter
      def self.instrument(_name, _payload = {})
        yield if block_given?
      end
    end

    # @return [URI] the resolved base URL
    attr_reader :base_url

    # @param api_key [String] a Neon API key (sent as a Bearer token)
    # @param base_url [String] override the API base URL (e.g. for testing)
    # @param timeout [Integer] read/open timeout in seconds
    # @param user_agent [String] override the User-Agent header
    # @param max_retries [Integer] retry attempts for 429 / transient 5xx /
    #   network errors (0 disables; default 2 → up to 3 total tries)
    # @param retry_base_delay [Float] base backoff in seconds (doubled per attempt)
    # @param retry_max_delay [Float] cap on any single backoff, in seconds
    # @param instrumenter [#instrument] observes requests (default: no-op)
    # @param sleeper [#call] receives the backoff seconds (injectable for tests)
    def initialize(api_key:, base_url: DEFAULT_BASE_URL, timeout: 30, user_agent: nil,
                   max_retries: 2, retry_base_delay: 0.5, retry_max_delay: 10.0,
                   instrumenter: NullInstrumenter, sleeper: ->(seconds) { sleep(seconds) })
      raise ConfigurationError, "an api_key is required" if api_key.nil? || api_key.to_s.empty?

      @api_key = api_key
      @base_url = URI.parse(ensure_trailing_slash(base_url))
      @timeout = timeout
      @user_agent = user_agent || "neon-api-ruby/#{NeonAPI::VERSION} (+#{base_url})"
      @max_retries = max_retries
      @retry_base_delay = retry_base_delay
      @retry_max_delay = retry_max_delay
      @instrumenter = instrumenter
      @sleeper = sleeper
    end

    # @!group HTTP verbs

    def get(path, query: nil, headers: {})
      request(:get, path, query: query, headers: headers)
    end

    def post(path, body: nil, query: nil, headers: {})
      request(:post, path, body: body, query: query, headers: headers)
    end

    def patch(path, body: nil, query: nil, headers: {})
      request(:patch, path, body: body, query: query, headers: headers)
    end

    def put(path, body: nil, query: nil, headers: {})
      request(:put, path, body: body, query: query, headers: headers)
    end

    def delete(path, body: nil, query: nil, headers: {})
      request(:delete, path, body: body, query: query, headers: headers)
    end

    # @!endgroup

    # Performs an HTTP request and returns the parsed response body.
    #
    # @param method [Symbol] :get, :post, :patch, :put, :delete
    # @param path [String] path relative to the base URL (no leading slash needed)
    # @param body [Hash, nil] request body, JSON-encoded if present
    # @param query [Hash, nil] query parameters
    # @param headers [Hash] additional request headers
    # @return [Hash, Array, nil] the parsed JSON response (or nil for empty bodies)
    # @raise [APIError] on any non-2xx response
    def request(method, path, body: nil, query: nil, headers: {})
      uri = build_uri(path, query)
      payload = { method: method, path: path, attempts: 0 }

      @instrumenter.instrument("request.neon_api", payload) do
        with_retries(method) do
          payload[:attempts] += 1
          req = build_request(method, uri, body, headers)
          response = perform(req, uri)
          payload[:status] = response.code.to_i
          handle(response, method, path)
        end
      end
    end

    private

    # Retry transient failures with exponential backoff + jitter. 429s are
    # retried for any method (the request was never processed); 5xx and network
    # errors only for idempotent methods (repeating a POST could double-write).
    def with_retries(method)
      attempt = 0
      begin
        yield
      rescue RateLimitError, ServerError, Error => e
        raise unless attempt < @max_retries && retryable?(e, method)

        @sleeper.call(retry_delay(e, attempt))
        attempt += 1
        retry
      end
    end

    def retryable?(error, method)
      return true if error.is_a?(RateLimitError) # 429: never processed, safe for any method
      # Other 4xx are caller errors; only 5xx (ServerError) and bare network
      # errors are transient — and those only for idempotent methods.
      return false if error.is_a?(APIError) && !error.is_a?(ServerError)

      idempotent?(method)
    end

    def idempotent?(method)
      IDEMPOTENT_METHODS.include?(method)
    end

    def retry_delay(error, attempt)
      retry_after = error.respond_to?(:retry_after) && error.retry_after
      return [retry_after.to_f, @retry_max_delay].min if retry_after

      # Exponential backoff with full jitter, capped.
      ceiling = [@retry_base_delay * (2**attempt), @retry_max_delay].min
      rand * ceiling
    end

    def perform(req, uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      http.request(req)
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError, IOError => e
      raise Error, "Network error talking to Neon (#{uri}): #{e.class}: #{e.message}"
    end

    def build_uri(path, query)
      # Merge against the base URL so the /api/v2/ prefix is always preserved.
      uri = URI.join(@base_url.to_s, path.to_s.sub(%r{\A/}, ""))
      if query && !query.empty?
        encoded = URI.encode_www_form(query.compact)
        uri.query = [uri.query, encoded].compact.join("&") unless encoded.empty?
      end
      uri
    end

    def build_request(method, uri, body, headers)
      klass = {
        get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch,
        put: Net::HTTP::Put, delete: Net::HTTP::Delete
      }.fetch(method) { raise ArgumentError, "unsupported HTTP method: #{method}" }

      req = klass.new(uri)
      default_headers.merge(headers).each { |k, v| req[k] = v }
      req.body = JSON.generate(body) if body
      req
    end

    def default_headers
      {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "User-Agent" => @user_agent
      }
    end

    def handle(response, method, path)
      status = response.code.to_i
      parsed = parse_body(response.body)
      return parsed if status.between?(200, 299)

      raise build_error(status, parsed, method, path, response)
    end

    def parse_body(raw)
      return nil if raw.nil? || raw.strip.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      # Non-JSON bodies (rare) are surfaced verbatim so callers aren't left blind.
      raw
    end

    def build_error(status, parsed, method, path, response)
      message = extract_message(parsed)
      request_id = response["x-neon-request-id"] || response["x-request-id"]
      ErrorFactory.klass_for(status).new(
        message,
        status: status,
        body: parsed,
        request: "#{method.to_s.upcase} /#{path.to_s.sub(%r{\A/}, "")}",
        request_id: request_id,
        retry_after: parse_retry_after(response["retry-after"])
      )
    end

    # Retry-After is either a number of seconds or an HTTP-date.
    def parse_retry_after(raw)
      return nil if raw.nil? || raw.to_s.strip.empty?
      return raw.to_f if raw.match?(/\A\s*\d+(\.\d+)?\s*\z/)

      [Time.httpdate(raw) - Time.now, 0.0].max
    rescue ArgumentError
      nil
    end

    def extract_message(parsed)
      return parsed if parsed.is_a?(String)
      return nil unless parsed.is_a?(Hash)

      # Neon returns errors as { "message": "...", "code": "..." } or
      # { "error": { "message": "..." } } depending on the endpoint.
      parsed["message"] ||
        parsed.dig("error", "message") ||
        parsed["error"] ||
        parsed["detail"]
    end

    def ensure_trailing_slash(url)
      url.end_with?("/") ? url : "#{url}/"
    end
  end
end
