# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

require_relative "../errors"
require_relative "../object"
require_relative "../version"

module NeonAPI
  module Auth
    # Shared HTTP plumbing for the Better Auth REST surface that managed Neon Auth
    # exposes under a project's hosted-auth `base_url`.
    #
    # It is not used directly — {BetterAuthClient} (email/password) and
    # {SocialAuth} (OAuth) subclass it. It provides Net::HTTP with the required
    # `Origin` header, an in-memory cookie jar (Better Auth tracks session state
    # via cookies), JSON encode/decode, and error mapping onto the same
    # {NeonAPI::APIError} hierarchy as the management API.
    class RestClient
      # @return [String] the hosted auth base URL (no trailing slash)
      attr_reader :base_url
      # @return [String] the Origin header sent with each request
      attr_reader :origin
      # @return [Hash{String=>String}] the current cookie jar
      attr_reader :cookies

      # @param base_url [String] the integration's hosted auth base URL
      #   (".../<db>/auth"), from {Branch#enable} / {Branch#config}
      # @param origin [String, nil] the `Origin` header value; defaults to the
      #   scheme + host (+ non-default port) of `base_url`
      # @param open_timeout [Integer] connect timeout in seconds
      # @param read_timeout [Integer] read timeout in seconds
      # @param user_agent [String, nil] override the User-Agent header
      def initialize(base_url:, origin: nil, open_timeout: 5, read_timeout: 5, user_agent: nil)
        raise ArgumentError, "base_url is required" if base_url.nil? || base_url.to_s.empty?

        @base_url = base_url.to_s.sub(%r{/+\z}, "")
        @uri = URI.parse(@base_url)
        @origin = origin || default_origin(@uri)
        @open_timeout = open_timeout
        @read_timeout = read_timeout
        @user_agent = user_agent || "neon-api-ruby/#{NeonAPI::VERSION}"
        @cookies = {}
      end

      # Replace the cookie jar — e.g. to resume a session stored between requests.
      # @param value [Hash, String] a name→value hash or a raw Cookie header string
      def cookies=(value)
        @cookies = value.is_a?(String) ? parse_cookie_pairs(value) : value.to_h
      end

      # The serialized `Cookie` header for the current jar (persist this to resume
      # the session later), or nil if the jar is empty.
      # @return [String, nil]
      def session_cookie
        return nil if @cookies.empty?

        @cookies.map { |k, v| "#{k}=#{v}" }.join("; ")
      end

      private

      def get(path, query: nil, headers: {})
        request(:get, path, query, nil, headers)
      end

      def post(path, body, headers: {})
        request(:post, path, nil, body, headers)
      end

      def request(method, path, query, body, headers)
        uri = URI.parse("#{@base_url}/#{path}")
        uri.query = URI.encode_www_form(query) if query && !query.empty?
        klass = method == :post ? Net::HTTP::Post : Net::HTTP::Get
        req = klass.new(uri)
        default_headers.merge(headers).each { |k, v| req[k] = v }
        req["Cookie"] = session_cookie if session_cookie
        req.body = JSON.generate(body) if body

        response = perform(req, uri)
        capture_cookies(response)
        handle(response, method, path)
      end

      def perform(req, uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = @open_timeout
        http.read_timeout = @read_timeout
        http.request(req)
      rescue Timeout::Error, Errno::ECONNREFUSED, SocketError, IOError => e
        raise Error, "Network error talking to Neon Auth (#{uri}): #{e.class}: #{e.message}"
      end

      def default_headers
        {
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "Origin" => @origin,
          "User-Agent" => @user_agent
        }
      end

      # Better Auth sets session state via Set-Cookie; capture the name=value
      # pairs so later calls on this instance carry the session.
      def capture_cookies(response)
        fields = response.get_fields("Set-Cookie")
        return unless fields

        fields.each do |raw|
          name, value = raw.split(";", 2).first.to_s.strip.split("=", 2)
          @cookies[name] = value unless name.nil? || name.empty?
        end
      end

      def handle(response, method, path)
        status = response.code.to_i
        parsed = parse_body(response.body)
        return wrap(parsed) if status.between?(200, 299)

        raise build_error(status, parsed, method, path)
      end

      def wrap(parsed)
        parsed.is_a?(::Hash) ? NeonAPI::Object.new(parsed) : parsed
      end

      def parse_body(raw)
        return nil if raw.nil? || raw.strip.empty?

        JSON.parse(raw)
      rescue JSON::ParserError
        raw
      end

      def build_error(status, parsed, method, path)
        ErrorFactory.klass_for(status).new(
          extract_message(parsed),
          status: status,
          body: parsed,
          request: "#{method.to_s.upcase} #{@base_url}/#{path}"
        )
      end

      def extract_message(parsed)
        return parsed if parsed.is_a?(String)
        return nil unless parsed.is_a?(Hash)

        parsed["message"] || parsed.dig("error", "message") || parsed["error"] || parsed["code"]
      end

      def default_origin(uri)
        on_default_port = (uri.scheme == "https" && uri.port == 443) ||
                          (uri.scheme == "http" && uri.port == 80)
        host = on_default_port ? uri.host : "#{uri.host}:#{uri.port}"
        "#{uri.scheme}://#{host}"
      end

      def parse_cookie_pairs(str)
        str.split(";").each_with_object({}) do |pair, acc|
          name, value = pair.strip.split("=", 2)
          acc[name] = value if name && !name.empty?
        end
      end
    end
  end
end
