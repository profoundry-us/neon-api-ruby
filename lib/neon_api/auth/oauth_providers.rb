# frozen_string_literal: true

require_relative "../object"
require_relative "../types"

module NeonAPI
  module Auth
    # Manage the OAuth providers (Google, GitHub, Microsoft, Vercel, ...) that a
    # Neon Auth integration offers for sign-in.
    #
    # This is the surface you wire into Rails OmniAuth: configure a provider here
    # (with your own OAuth credentials for production), then point OmniAuth at the
    # Neon Auth project. See {NeonAPI::OmniAuth} and docs/rails_omniauth.md.
    #
    # Accessed via `client.auth(project_id, branch_id).oauth_providers`.
    #
    # @example
    #   providers = client.auth(project_id, branch_id).oauth_providers
    #   providers.list
    #   providers.add(id: "google", client_id: "...", client_secret: "...")
    #   providers.update("google", client_secret: "rotated-secret")
    #   providers.delete("google")
    class OAuthProviders
      # Provider ids Neon Auth accepts for the `id` field.
      SUPPORTED = %w[google github microsoft vercel].freeze

      # @param connection [NeonAPI::Connection]
      # @param base_path [String] the branch auth base path, e.g.
      #   "projects/{pid}/branches/{bid}/auth"
      def initialize(connection:, base_path:)
        @connection = connection
        @path = "#{base_path}/oauth_providers"
      end

      # List configured OAuth providers.
      # @return [Types::ListNeonAuthOauthProvidersResponse]
      def list
        wrap(@connection.get(@path), Types::ListNeonAuthOauthProvidersResponse)
      end
      alias all list

      # Add an OAuth provider to the integration.
      #
      # If `client_id`/`client_secret` are omitted, Neon uses shared development
      # keys — fine for prototyping, but you should always supply your own
      # credentials in production.
      #
      # @param id [String] one of {SUPPORTED} ("google", "github", ...)
      # @param client_id [String, nil] your OAuth app client id
      # @param client_secret [String, nil] your OAuth app client secret
      # @param microsoft_tenant_id [String, nil] required for some Microsoft setups
      # @return [Types::NeonAuthOauthProvider]
      def add(id:, client_id: nil, client_secret: nil, microsoft_tenant_id: nil)
        validate_id!(id)
        body = compact(
          id: id,
          client_id: client_id,
          client_secret: client_secret,
          microsoft_tenant_id: microsoft_tenant_id
        )
        wrap(@connection.post(@path, body: body), Types::NeonAuthOauthProvider)
      end
      alias create add

      # Update an existing provider's credentials.
      #
      # @param id [String] the provider id to update
      # @param client_id [String, nil]
      # @param client_secret [String, nil]
      # @param microsoft_tenant_id [String, nil]
      # @return [Types::NeonAuthOauthProvider]
      def update(id, client_id: nil, client_secret: nil, microsoft_tenant_id: nil)
        validate_id!(id)
        body = compact(
          id: id,
          client_id: client_id,
          client_secret: client_secret,
          microsoft_tenant_id: microsoft_tenant_id
        )
        wrap(@connection.patch("#{@path}/#{id}", body: body), Types::NeonAuthOauthProvider)
      end

      # Remove a provider from the integration.
      # @param id [String]
      # @return [NeonAPI::Object]
      def delete(id)
        validate_id!(id)
        wrap(@connection.delete("#{@path}/#{id}"))
      end
      alias remove delete

      private

      def validate_id!(id)
        return if SUPPORTED.include?(id.to_s)

        raise ArgumentError,
              "unsupported OAuth provider id #{id.inspect}; expected one of #{SUPPORTED.join(", ")}"
      end

      def compact(hash)
        hash.compact
      end

      def wrap(payload, type = Object)
        Types.wrap(payload, type)
      end
    end
  end
end
