# frozen_string_literal: true

require_relative "connection"
require_relative "object"
require_relative "auth/branch"

module NeonAPI
  # The primary entry point for talking to the Neon API.
  #
  # @example Authenticate from an environment variable (NEON_API_KEY)
  #   client = NeonAPI::Client.from_environ
  #   client.me.email
  #
  # @example Authenticate with an explicit key
  #   client = NeonAPI::Client.new(api_key: "neon_api_key_...")
  #
  # @example Reach into Neon Auth for a project's default branch
  #   auth = client.auth("project-id", "br-default-123")
  #   auth.enable(auth_provider: "better_auth")
  #   auth.oauth_providers.add(id: "google", client_id: "...", client_secret: "...")
  #
  # The management surface mirrors the official Python client
  # (https://github.com/neondatabase/neon-api-python); Neon Auth support is the
  # part that goes beyond it.
  class Client
    # @return [NeonAPI::Connection] the underlying HTTP connection
    attr_reader :connection

    # Build a client from the NEON_API_KEY environment variable.
    #
    # @param env [String] the variable name to read (default "NEON_API_KEY")
    # @param options [Hash] forwarded to {#initialize} (e.g. :base_url, :timeout)
    # @raise [ConfigurationError] if the variable is unset
    # @return [Client]
    def self.from_environ(env: "NEON_API_KEY", **options)
      key = ENV.fetch(env, nil)
      raise ConfigurationError, "environment variable #{env} is not set" if key.nil? || key.empty?

      new(api_key: key, **options)
    end

    # Alias matching the Python client's `from_token` factory.
    # @return [Client]
    def self.from_token(token, **options)
      new(api_key: token, **options)
    end

    # @param api_key [String] a Neon API key
    # @param base_url [String] override the API base URL
    # @param timeout [Integer] request timeout in seconds
    def initialize(api_key:, base_url: Connection::DEFAULT_BASE_URL, timeout: 30)
      @connection = Connection.new(api_key: api_key, base_url: base_url, timeout: timeout)
    end

    # @!group Account

    # The currently authenticated user.
    # @return [NeonAPI::Object]
    def me
      wrap(@connection.get("users/me"))
    end

    # @!endgroup

    # @!group API keys

    # @return [NeonAPI::Object] list of API keys ({ "api_keys" => [...] } style)
    def api_keys
      wrap(@connection.get("api_keys"))
    end

    # @param key_name [String] a human-readable name for the new key
    # @return [NeonAPI::Object] the created key (includes the secret, shown once)
    def api_key_create(key_name)
      wrap(@connection.post("api_keys", body: { key_name: key_name }))
    end

    # @param key_id [String, Integer]
    # @return [NeonAPI::Object]
    def api_key_revoke(key_id)
      wrap(@connection.delete("api_keys/#{key_id}"))
    end

    # @!endgroup

    # @!group Projects

    # @param params [Hash] optional pagination/search params (e.g. :limit, :cursor)
    # @return [NeonAPI::Object]
    def projects(**params)
      wrap(@connection.get("projects", query: params))
    end

    # @param project_id [String]
    # @return [NeonAPI::Object]
    def project(project_id)
      wrap(@connection.get("projects/#{project_id}"))
    end

    # @param project [Hash] the "project" payload Neon expects
    # @return [NeonAPI::Object]
    def project_create(project: {})
      wrap(@connection.post("projects", body: { project: project }))
    end

    # @param project_id [String]
    # @param project [Hash] fields to update
    # @return [NeonAPI::Object]
    def project_update(project_id, project:)
      wrap(@connection.patch("projects/#{project_id}", body: { project: project }))
    end

    # @param project_id [String]
    # @return [NeonAPI::Object]
    def project_delete(project_id)
      wrap(@connection.delete("projects/#{project_id}"))
    end

    # @!endgroup

    # @!group Branches

    # @param project_id [String]
    # @return [NeonAPI::Object]
    def branches(project_id, **params)
      wrap(@connection.get("projects/#{project_id}/branches", query: params))
    end

    # @param project_id [String]
    # @param branch_id [String]
    # @return [NeonAPI::Object]
    def branch(project_id, branch_id)
      wrap(@connection.get("projects/#{project_id}/branches/#{branch_id}"))
    end

    # @param project_id [String]
    # @param branch [Hash] the "branch" payload
    # @return [NeonAPI::Object]
    def branch_create(project_id, branch: {})
      wrap(@connection.post("projects/#{project_id}/branches", body: { branch: branch }))
    end

    # @!endgroup

    # Access the Neon Auth surface for a specific project + branch.
    #
    # Neon Auth is scoped to a branch (most apps use the project's default
    # branch). The returned object exposes integration management, OAuth provider
    # configuration, user management, and runtime JWT verification.
    #
    # @param project_id [String]
    # @param branch_id [String]
    # @return [NeonAPI::Auth::Branch]
    def auth(project_id, branch_id)
      Auth::Branch.new(connection: @connection, project_id: project_id, branch_id: branch_id)
    end

    private

    def wrap(payload)
      payload.is_a?(::Hash) ? Object.new(payload) : payload
    end
  end
end
