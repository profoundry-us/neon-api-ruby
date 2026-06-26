# frozen_string_literal: true

require_relative "neon_api/version"
require_relative "neon_api/errors"
require_relative "neon_api/object"
require_relative "neon_api/connection"
require_relative "neon_api/client"
require_relative "neon_api/auth/branch"
require_relative "neon_api/auth/oauth_providers"
require_relative "neon_api/auth/users"
require_relative "neon_api/auth/jwt_verifier"
require_relative "neon_api/auth/rest_client"
require_relative "neon_api/auth/better_auth_client"
require_relative "neon_api/auth/social_auth"
require_relative "neon_api/omniauth"

# Ruby client for the Neon API (https://neon.tech), with first-class Neon Auth
# support for Ruby on Rails apps.
#
# @example Quick start
#   client = NeonAPI.from_environ            # reads NEON_API_KEY
#   client.me.email
#
#   auth = client.auth(project_id, branch_id)
#   auth.enable(auth_provider: "better_auth")
#   auth.oauth_providers.add(id: "github", client_id: "...", client_secret: "...")
module NeonAPI
  class << self
    # Build a {Client} from an explicit API key.
    # @param api_key [String]
    # @return [Client]
    def new(api_key:, **options)
      Client.new(api_key: api_key, **options)
    end

    # Build a {Client} from the NEON_API_KEY environment variable.
    # @return [Client]
    def from_environ(**options)
      Client.from_environ(**options)
    end
    alias from_env from_environ

    # Build a {Client} from an API key/token.
    # @return [Client]
    def from_token(token, **options)
      Client.from_token(token, **options)
    end
  end
end
