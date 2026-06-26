# frozen_string_literal: true

require "uri"

module NeonAPI
  # Helpers for treating Neon Auth as an OIDC provider via the
  # `omniauth_openid_connect` strategy.
  #
  # @note **This does not work against managed Neon Auth (the `better_auth`
  #   backend).** Managed Neon Auth is not an OIDC provider — it serves no OIDC
  #   discovery document, `/authorize`, `/token` (OIDC), or `/userinfo` endpoint
  #   (only JWKS), and offers no third-party OAuth client registration, so this
  #   relying-party flow cannot complete. See
  #   https://github.com/profoundry-us/neon-api-ruby/issues/2.
  #
  #   For server-rendered Rails login on managed Neon Auth, use
  #   {NeonAPI::Auth::BetterAuthClient} (sign-in → token) plus
  #   {NeonAPI::Auth::JWTVerifier}. These helpers remain only for a self-hosted
  #   Better Auth deployment that has enabled the (non-managed) oidc-provider
  #   plugin, or another genuine OIDC provider fronting Neon.
  #
  # The endpoints follow Neon Auth's hosted-auth base URL. If your provider uses
  # a non-default layout, every derived value can be overridden via keyword args.
  #
  # @example config/initializers/omniauth.rb (self-hosted OIDC only)
  #   integration = Rails.application.config.x.neon_auth   # cached integration
  #   Rails.application.config.middleware.use OmniAuth::Builder do
  #     provider :openid_connect, NeonAPI::OmniAuth.openid_connect_options(
  #       integration: integration,
  #       client_id: ENV.fetch("NEON_AUTH_CLIENT_ID"),
  #       client_secret: ENV.fetch("NEON_AUTH_CLIENT_SECRET"),
  #       redirect_uri: "https://app.example.com/auth/openid_connect/callback"
  #     )
  #   end
  module OmniAuth
    module_function

    # Build an options hash for `provider :openid_connect, ...`.
    #
    # @param integration [#to_h, Hash] a Neon Auth integration (response of
    #   enable/config); used to derive `base_url`, `jwks_url`, and the issuer
    # @param client_id [String] your Neon Auth / OAuth client id
    # @param client_secret [String] your Neon Auth / OAuth client secret
    # @param redirect_uri [String] the callback URL registered for your app
    # @param name [Symbol] the OmniAuth provider name (default :openid_connect)
    # @param scope [Array<Symbol>] OIDC scopes to request
    # @param issuer [String, nil] override the issuer (default: integration base_url)
    # @param overrides [Hash] deep-merged onto the resulting options
    # @return [Hash] options for OmniAuth's openid_connect strategy
    def openid_connect_options(integration:, client_id:, client_secret:, redirect_uri:,
                               name: :openid_connect, scope: %i[openid email profile],
                               issuer: nil, **overrides)
      data = to_hash(integration)
      base = require_value(data, "base_url")
      iss = issuer || base
      uri = URI.parse(base)

      options = {
        name: name,
        scope: scope,
        response_type: :code,
        issuer: iss,
        discovery: true,
        client_options: {
          identifier: client_id,
          secret: client_secret,
          redirect_uri: redirect_uri,
          scheme: uri.scheme,
          host: uri.host,
          port: uri.port,
          authorization_endpoint: join(base, "authorize"),
          token_endpoint: join(base, "token"),
          userinfo_endpoint: join(base, "userinfo"),
          jwks_uri: data["jwks_url"] || join(base, ".well-known/jwks.json")
        }
      }

      deep_merge(options, overrides)
    end

    # Extract just the JWKS URL from an integration, for use with
    # {NeonAPI::Auth::JWTVerifier}.
    # @param integration [#to_h, Hash]
    # @return [String]
    def jwks_url(integration)
      data = to_hash(integration)
      require_value(data, "jwks_url")
    end

    # @api private
    def to_hash(integration)
      if integration.respond_to?(:to_h)
        integration.to_h
      elsif integration.is_a?(Hash)
        integration
      else
        raise ArgumentError, "integration must respond to #to_h or be a Hash"
      end
    end

    # @api private
    def require_value(hash, key)
      value = hash[key] || hash[key.to_sym]
      raise ArgumentError, "integration is missing #{key.inspect}" if value.nil? || value.to_s.empty?

      value
    end

    # @api private
    def join(base, path)
      "#{base.sub(%r{/+\z}, "")}/#{path}"
    end

    # @api private
    def deep_merge(base, other)
      base.merge(other) do |_key, a, b|
        a.is_a?(Hash) && b.is_a?(Hash) ? deep_merge(a, b) : b
      end
    end
  end
end
