# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

require_relative "../errors"
require_relative "../object"
require_relative "../version"

module NeonAPI
  module Auth
    # Server-side client for a managed Neon Auth project's Better Auth REST API.
    #
    # Managed Neon Auth (the `better_auth` backend) is **not** an OIDC/OAuth2
    # provider: it exposes no OIDC discovery, `/authorize`, `/token` (OIDC), or
    # `/userinfo`, so the `omniauth_openid_connect` flow cannot complete against
    # it (see {NeonAPI::OmniAuth}). What it *does* expose is Better Auth's REST
    # API under the integration's `base_url` — which works server-side and is the
    # realistic path for a server-rendered Rails app:
    #
    # * `POST <base_url>/sign-up/email`
    # * `POST <base_url>/sign-in/email`  → sets a session cookie
    # * `GET  <base_url>/get-session`
    # * `GET  <base_url>/token`          → the EdDSA JWT {JWTVerifier} consumes
    # * `POST <base_url>/sign-out`
    # * `GET  <base_url>/ok`             (health)
    #
    # These endpoints enforce a CSRF guard requiring an `Origin` header that
    # matches the auth host; this client sends it automatically (derived from
    # `base_url`, override with `origin:`).
    #
    # The client keeps an in-memory cookie jar, so a sign-in followed by {#token}
    # on the same instance just works. To resume a session across requests (e.g.
    # from a value stored in the Rails session), set {#cookies=} / read
    # {#session_cookie}.
    #
    # @example Server-side password login in Rails
    #   ba = client.auth(project_id, branch_id).better_auth   # base_url from config
    #   ba.sign_in_email(email: params[:email], password: params[:password])
    #   claims = verifier.verify(ba.token)
    #   user = User.find_or_create_by!(neon_auth_id: claims.sub)
    class BetterAuthClient
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

      # The serialized `Cookie` header for the current jar (persist this to
      # resume the Better Auth session later), or nil if the jar is empty.
      # @return [String, nil]
      def session_cookie
        return nil if @cookies.empty?

        @cookies.map { |k, v| "#{k}=#{v}" }.join("; ")
      end

      # Register a new user with email + password.
      # @param email [String]
      # @param password [String]
      # @param name [String, nil]
      # @param extra [Hash] any additional Better Auth fields
      # @return [NeonAPI::Object] the parsed response
      def sign_up_email(email:, password:, name: nil, **extra)
        post("sign-up/email", { name: name, email: email, password: password }.compact.merge(extra))
      end

      # Sign in with email + password. On success the response sets a session
      # cookie, which this client captures for subsequent {#token}/{#session}.
      # @return [NeonAPI::Object]
      def sign_in_email(email:, password:, **extra)
        post("sign-in/email", { email: email, password: password }.merge(extra))
      end

      # The current session (requires an active session cookie).
      # @return [NeonAPI::Object, nil]
      def session
        get("get-session")
      end
      alias get_session session

      # Exchange the current session for a signed EdDSA JWT — the token
      # {JWTVerifier} verifies.
      # @return [String, nil] the JWT, or nil if none was returned
      def token
        result = get("token")
        result.is_a?(NeonAPI::Object) ? result["token"] : nil
      end

      # Sign out and clear the local cookie jar.
      # @return [NeonAPI::Object, nil]
      def sign_out
        result = post("sign-out", {})
        @cookies = {}
        result
      end

      # Health check (`GET /ok`).
      # @return [Boolean]
      def healthy?
        get("ok")
        true
      rescue NeonAPI::Error
        false
      end

      private

      def get(path, headers: {})
        request(:get, path, nil, headers)
      end

      def post(path, body, headers: {})
        request(:post, path, body, headers)
      end

      def request(method, path, body, headers)
        uri = URI.parse("#{@base_url}/#{path}")
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
