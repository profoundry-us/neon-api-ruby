# frozen_string_literal: true

require_relative "jwt_verifier"
require_relative "social_auth"
require_relative "better_auth_client"

module NeonAPI
  module Auth
    # Process-wide configuration for the optional convenience layer: derive Neon
    # Auth settings once, then reuse memoized {JWTVerifier} / {SocialAuth} /
    # {BetterAuthClient} instances instead of re-deriving them in every app.
    #
    # Framework-agnostic — usable from any Ruby app — but most valuable under
    # Rails, where the {Railtie} sets environment defaults and {Controller} wires
    # the request flow.
    #
    # @example config/initializers/neon_auth.rb
    #   NeonAPI::Auth.configure do |c|
    #     c.base_url = ENV["NEON_AUTH_BASE_URL"]      # jwks_url derived unless set
    #     c.find_user { |claims| User.find_or_create_from_neon_claims(claims) }
    #   end
    class Configuration
      # @return [String, nil] hosted auth base URL (".../<db>/auth")
      attr_accessor :base_url
      # @return [String, nil] Origin header override for social / better_auth
      attr_accessor :origin
      # @return [Hash] extra options forwarded to {JWTVerifier} (e.g. :issuer, :audience)
      attr_accessor :verifier_options
      # @return [true, false, nil] explicit enabled flag; nil = auto (base_url present)
      attr_accessor :enabled

      # @return [String, nil] override the derived JWKS URL
      attr_writer :jwks_url

      def initialize
        @verifier_options = {}
      end

      # JWKS URL — derived from {#base_url} unless set explicitly.
      # @return [String, nil]
      def jwks_url
        return @jwks_url unless blank?(@jwks_url)
        return nil if blank?(base_url)

        "#{base_url.sub(%r{/+\z}, "")}/.well-known/jwks.json"
      end

      # Whether Neon Auth is active. Defaults to "base_url present"; under Rails
      # the {Railtie} defaults it to false in the test environment.
      # @return [Boolean]
      def enabled?
        @enabled.nil? ? !blank?(base_url) : !!@enabled
      end

      # Register (or read) the identity hook: maps verified {Claims} to your
      # app's user. This is the one genuinely app-specific seam.
      # @yieldparam claims [NeonAPI::Auth::Claims]
      # @return [Proc, nil]
      def find_user(&block)
        @find_user = block if block
        @find_user
      end

      # Invoke the identity hook with verified claims.
      # @raise [NeonAPI::ConfigurationError] if no hook is registered
      def resolve_user(claims)
        unless @find_user
          raise NeonAPI::ConfigurationError,
                "NeonAPI::Auth identity hook is not set — call `config.find_user { |claims| ... }`"
        end

        @find_user.call(claims)
      end

      # @return [JWTVerifier]
      def build_verifier(**opts)
        url = require_value!(jwks_url, "jwks_url (or base_url)")
        JWTVerifier.new(jwks_url: url, **verifier_options, **opts)
      end

      # @return [SocialAuth]
      def build_social(**opts)
        SocialAuth.new(base_url: require_value!(base_url, "base_url"), origin: origin, **opts)
      end

      # @return [BetterAuthClient]
      def build_better_auth(**opts)
        BetterAuthClient.new(base_url: require_value!(base_url, "base_url"), origin: origin, **opts)
      end

      private

      def require_value!(value, name)
        raise NeonAPI::ConfigurationError, "NeonAPI::Auth #{name} is not configured" if blank?(value)

        value
      end

      def blank?(value)
        value.nil? || value.to_s.empty?
      end
    end

    class << self
      # Configure the convenience layer. Re-running rebuilds the memoized clients.
      # @yieldparam config [Configuration]
      # @return [Configuration]
      def configure
        yield(config) if block_given?
        reset_clients!
        config
      end

      # @return [Configuration] the current configuration
      def config
        @config ||= Configuration.new
      end

      # Reset all configuration and memoized clients (useful in test setup).
      # @return [void]
      def reset!
        @config = Configuration.new
        reset_clients!
      end

      # @return [Boolean] whether Neon Auth is active
      def enabled?
        config.enabled?
      end

      # @return [JWTVerifier] memoized verifier built from {config}
      def verifier
        @verifier ||= client_mutex.synchronize { @verifier ||= config.build_verifier }
      end

      # @return [SocialAuth] memoized social client built from {config}
      def social
        @social ||= client_mutex.synchronize { @social ||= config.build_social }
      end

      # @return [BetterAuthClient] memoized email/password client built from {config}
      def better_auth
        @better_auth ||= client_mutex.synchronize { @better_auth ||= config.build_better_auth }
      end

      # Map verified claims to your app's user via the configured identity hook.
      def find_user(claims)
        config.resolve_user(claims)
      end

      private

      def client_mutex
        @client_mutex ||= Mutex.new
      end

      def reset_clients!
        @verifier = @social = @better_auth = nil
      end
    end
  end
end
