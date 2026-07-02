# frozen_string_literal: true

require_relative "../object"
require_relative "../types"
require_relative "oauth_providers"
require_relative "users"
require_relative "jwt_verifier"
require_relative "better_auth_client"
require_relative "social_auth"

module NeonAPI
  module Auth
    # The Neon Auth surface for a single project + branch.
    #
    # Neon Auth integrations are scoped to a branch (most apps operate on the
    # project's default branch). This object is the hub for everything auth:
    #
    # * Lifecycle:        {#enable}, {#config}, {#update}, {#disable}
    # * OAuth providers:  {#oauth_providers}  (wire these into Rails OmniAuth)
    # * Users:            {#users}
    # * Runtime verify:   {#jwt_verifier}     (validate Neon Auth JWTs in Rails)
    #
    # Obtain one with `client.auth(project_id, branch_id)`.
    #
    # @example Enable Neon Auth and configure Google sign-in
    #   auth = client.auth(project_id, branch_id)
    #   integration = auth.enable(auth_provider: "better_auth")
    #   integration.jwks_url   #=> "https://.../.well-known/jwks.json"
    #   auth.oauth_providers.add(id: "google", client_id: "...", client_secret: "...")
    class Branch
      # Auth provider backends Neon Auth supports for the integration itself.
      AUTH_PROVIDERS = %w[better_auth stack].freeze

      # @return [String]
      attr_reader :project_id, :branch_id

      # @param connection [NeonAPI::Connection]
      # @param project_id [String]
      # @param branch_id [String]
      def initialize(connection:, project_id:, branch_id:)
        @connection = connection
        @project_id = project_id
        @branch_id = branch_id
        @base_path = "projects/#{project_id}/branches/#{branch_id}/auth"
      end

      # Enable the Neon Auth integration on this branch.
      #
      # The response is shown in full only once and contains the credentials your
      # app needs: `pub_client_key`, `secret_server_key`, `jwks_url`,
      # `schema_name`, `table_name`, and `base_url`. Store the secret securely.
      #
      # @param auth_provider [String] one of {AUTH_PROVIDERS} (default "better_auth")
      # @param database_name [String, nil] which database to provision into
      # @return [Types::NeonAuthCreateIntegrationResponse]
      def enable(auth_provider: "better_auth", database_name: nil)
        body = { auth_provider: auth_provider, database_name: database_name }.compact
        wrap(@connection.post(@base_path, body: body), Types::NeonAuthCreateIntegrationResponse)
      end
      alias create enable

      # Fetch the current integration configuration.
      # @return [Types::NeonAuthIntegration] includes `jwks_url`, `base_url`, `auth_provider`, ...
      def config
        wrap(@connection.get(@base_path), Types::NeonAuthIntegration)
      end
      alias get config

      # Update integration settings (e.g. the display name).
      # @param attributes [Hash] fields to update (e.g. :name)
      # @return [Types::NeonAuthConfigResponse]
      def update(**attributes)
        wrap(@connection.patch("#{@base_path}/config", body: attributes), Types::NeonAuthConfigResponse)
      end

      # Disable the integration.
      # @param delete_data [Boolean] also drop the synced auth data (default false)
      # @return [NeonAPI::Object, nil]
      def disable(delete_data: false)
        wrap(@connection.delete(@base_path, body: { delete_data: delete_data }))
      end
      alias destroy disable

      # OAuth provider management for this integration.
      # @return [NeonAPI::Auth::OAuthProviders]
      def oauth_providers
        @oauth_providers ||= OAuthProviders.new(connection: @connection, base_path: @base_path)
      end

      # User management for this integration.
      # @return [NeonAPI::Auth::Users]
      def users
        @users ||= Users.new(connection: @connection, base_path: @base_path)
      end

      # A server-side social (OAuth) sign-in client for this integration —
      # "Continue with Google" for a server-rendered Rails app. The `base_url`
      # is read from {#config} the first time it's needed unless you pass it.
      #
      #   social = auth.social(base_url: integration.base_url)
      #   init = social.sign_in(provider: "google", callback_url: "https://app/auth/neon/callback")
      #
      # @param base_url [String, nil] override; fetched from {#config} when nil
      # @param options [Hash] forwarded to {NeonAPI::Auth::SocialAuth}
      # @return [NeonAPI::Auth::SocialAuth]
      def social(base_url: nil, **options)
        url = base_url || config.base_url
        SocialAuth.new(base_url: url, **options)
      end

      # A server-side Better Auth REST client for this integration.
      #
      # This is the working path for server-rendered Rails login on managed
      # Neon Auth (sign-up / sign-in / get-session / token). The `base_url` is
      # read from {#config} the first time it's needed unless you pass it.
      #
      #   ba = auth.better_auth(base_url: integration.base_url)
      #   ba.sign_in_email(email: email, password: password)
      #   claims = auth.jwt_verifier.verify(ba.token)
      #
      # @param base_url [String, nil] override; fetched from {#config} when nil
      # @param options [Hash] forwarded to {NeonAPI::Auth::BetterAuthClient}
      # @return [NeonAPI::Auth::BetterAuthClient]
      def better_auth(base_url: nil, **options)
        url = base_url || config.base_url
        BetterAuthClient.new(base_url: url, **options)
      end

      # A runtime JWT verifier wired to this integration's JWKS URL.
      #
      # The JWKS URL is read from {#config} the first time it's needed (and
      # cached). If you already have it, pass it to avoid the extra API call:
      #
      #   auth.jwt_verifier(jwks_url: integration.jwks_url)
      #
      # @param jwks_url [String, nil] override; fetched from {#config} when nil
      # @param options [Hash] forwarded to {NeonAPI::Auth::JWTVerifier}
      # @return [NeonAPI::Auth::JWTVerifier]
      def jwt_verifier(jwks_url: nil, **options)
        url = jwks_url || config.jwks_url
        JWTVerifier.new(jwks_url: url, **options)
      end

      private

      def wrap(payload, type = Object)
        Types.wrap(payload, type)
      end
    end
  end
end
