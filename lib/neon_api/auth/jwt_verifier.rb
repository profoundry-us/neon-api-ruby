# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

require_relative "../errors"

module NeonAPI
  module Auth
    # Raised when a Neon Auth JWT fails verification for any reason.
    class InvalidTokenError < NeonAPI::Error; end

    # Raised specifically when a token is well-formed and correctly signed but
    # has expired. Subclass of {InvalidTokenError} so a single rescue catches all.
    class TokenExpiredError < InvalidTokenError; end

    # The verified claims of a Neon Auth JWT.
    #
    # Exposes the well-known Neon Auth claims as readers and supports both hash-
    # and method-style access to any additional claims.
    #
    # @example
    #   claims = verifier.verify(token)
    #   claims.sub      #=> the Neon Auth user id (neon_auth.user.id)
    #   claims.email
    #   claims["role"]  #=> "authenticated"
    class Claims
      # @param payload [Hash] the decoded, verified JWT payload
      def initialize(payload)
        @payload = payload
      end

      # @return [String, nil] the user id (JWT `sub` claim)
      def sub
        @payload["sub"]
      end
      alias user_id sub

      # @return [String, nil]
      def email
        @payload["email"]
      end

      # @return [String, nil] typically "authenticated"
      def role
        @payload["role"]
      end

      # @return [Time, nil] expiry time
      def expires_at
        @payload["exp"] && Time.at(@payload["exp"])
      end

      # @return [Time, nil] issued-at time
      def issued_at
        @payload["iat"] && Time.at(@payload["iat"])
      end

      def [](key)
        @payload[key.to_s]
      end

      # @return [Hash] the raw verified payload
      def to_h
        @payload
      end

      def respond_to_missing?(name, include_private = false)
        @payload.key?(name.to_s) || super
      end

      def method_missing(name, *_args)
        key = name.to_s
        @payload.key?(key) ? @payload[key] : super
      end
    end

    # Verifies Neon Auth JWTs against a project's JWKS endpoint.
    #
    # This is the runtime half of Neon Auth for a Ruby backend: your frontend (or
    # Neon Auth itself) issues a signed JWT, your Rails app extracts it from the
    # `Authorization: Bearer <token>` header, and this class checks the signature,
    # expiry, and (optionally) issuer/audience — then hands back the {Claims}.
    #
    # Public keys are fetched from the JWKS URL and cached. On encountering a
    # token signed with an unknown key id (`kid`) — i.e. after key rotation — the
    # cache is refreshed once automatically before failing.
    #
    # Neon Auth signs with EdDSA (Ed25519) by default. Verifying EdDSA tokens
    # requires the `jwt` gem's Ed25519 support (the `rbnacl` gem). RS256 projects
    # need no extra dependency.
    #
    # @example Rails (typically memoized in a service or initializer)
    #   verifier = NeonAPI::Auth::JWTVerifier.new(jwks_url: ENV["NEON_AUTH_JWKS_URL"])
    #   claims = verifier.verify(request.headers["Authorization"].sub(/\ABearer /, ""))
    #   current_user = User.find_by(neon_auth_id: claims.sub)
    class JWTVerifier
      DEFAULT_ALGORITHMS = %w[EdDSA RS256].freeze
      DEFAULT_CACHE_TTL = 600 # seconds

      # @param jwks_url [String] the project's JWKS URL (from the integration)
      # @param algorithms [Array<String>] permitted signing algorithms
      # @param issuer [String, nil] if set, the `iss` claim must match
      # @param audience [String, nil] if set, the `aud` claim must match
      # @param leeway [Integer] clock-skew leeway in seconds for time claims
      # @param cache_ttl [Integer] seconds to cache the JWKS before refetching
      # @param open_timeout [Integer] JWKS fetch open timeout
      # @param read_timeout [Integer] JWKS fetch read timeout
      def initialize(jwks_url:, algorithms: DEFAULT_ALGORITHMS, issuer: nil, audience: nil,
                     leeway: 0, cache_ttl: DEFAULT_CACHE_TTL, open_timeout: 5, read_timeout: 5)
        raise ArgumentError, "jwks_url is required" if jwks_url.nil? || jwks_url.empty?

        require_jwt!
        @jwks_url = jwks_url
        @algorithms = Array(algorithms)
        @issuer = issuer
        @audience = audience
        @leeway = leeway
        @cache_ttl = cache_ttl
        @open_timeout = open_timeout
        @read_timeout = read_timeout
        @mutex = Mutex.new
        @jwks = nil
        @jwks_fetched_at = nil
      end

      # Verify a token and return its claims.
      #
      # @param token [String] the raw JWT (no "Bearer " prefix)
      # @param audience [String, nil] override the configured audience for this call
      # @return [Claims]
      # @raise [TokenExpiredError] if the token has expired
      # @raise [InvalidTokenError] for any other validation failure
      def verify(token, audience: @audience)
        raise InvalidTokenError, "token is empty" if token.nil? || token.to_s.strip.empty?

        payload, = decode(token, audience)
        Claims.new(payload)
      rescue JWT::ExpiredSignature => e
        raise TokenExpiredError, "token has expired: #{e.message}"
      rescue JWT::DecodeError, JWT::JWKError => e
        raise InvalidTokenError, e.message
      end

      # Verify a token, returning the {Claims} or `nil` instead of raising.
      # @return [Claims, nil]
      def verify?(token, audience: @audience)
        verify(token, audience: audience)
      rescue InvalidTokenError
        nil
      end

      # Force a refresh of the cached JWKS on the next verification.
      # @return [void]
      def reset_cache!
        @mutex.synchronize do
          @jwks = nil
          @jwks_fetched_at = nil
        end
      end

      private

      def decode(token, audience)
        options = {
          algorithms: @algorithms,
          jwks: method(:key_loader),
          verify_expiration: true,
          leeway: @leeway
        }
        if @issuer
          options[:verify_iss] = true
          options[:iss] = @issuer
        end
        if audience
          options[:verify_aud] = true
          options[:aud] = audience
        end

        JWT.decode(token, nil, true, **options)
      end

      # JWT key loader. The `jwt` gem calls this with `{ kid:, invalidate: }` and
      # expects a JWKS hash (`{ "keys" => [...] }`) back. When `invalidate` is
      # true (unknown kid, e.g. after key rotation) we refetch before answering.
      def key_loader(options)
        refresh = options[:invalidate] || jwks_stale?
        fetch_jwks(force: refresh)
      end

      def jwks_stale?
        @jwks.nil? || @jwks_fetched_at.nil? ||
          (Time.now - @jwks_fetched_at) > @cache_ttl
      end

      def fetch_jwks(force: false)
        @mutex.synchronize do
          return @jwks if @jwks && !force && !jwks_stale?

          @jwks = download_jwks
          @jwks_fetched_at = Time.now
          @jwks
        end
      end

      def download_jwks
        uri = URI.parse(@jwks_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = @open_timeout
        http.read_timeout = @read_timeout
        response = http.get(uri.request_uri)
        unless response.code.to_i.between?(200, 299)
          raise InvalidTokenError, "failed to fetch JWKS (HTTP #{response.code}) from #{@jwks_url}"
        end

        JSON.parse(response.body)
      rescue Timeout::Error, Errno::ECONNREFUSED, SocketError, IOError => e
        raise InvalidTokenError, "network error fetching JWKS from #{@jwks_url}: #{e.message}"
      rescue JSON::ParserError => e
        raise InvalidTokenError, "JWKS endpoint returned invalid JSON: #{e.message}"
      end

      def require_jwt!
        require "jwt"
      rescue LoadError
        raise NeonAPI::ConfigurationError,
              "the `jwt` gem is required for JWT verification. Add `gem \"jwt\"` to your Gemfile. " \
              "Neon Auth uses EdDSA by default, which also needs `gem \"rbnacl\"`."
      end
    end
  end
end
