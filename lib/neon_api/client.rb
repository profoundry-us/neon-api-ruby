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
    # @param options [Hash] forwarded to {Connection} (e.g. :base_url, :timeout,
    #   :max_retries, :instrumenter)
    def initialize(api_key:, **options)
      @connection = Connection.new(api_key: api_key, **options)
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

    # @!group Databases (branch-scoped)

    # @return [NeonAPI::Object]
    def databases(project_id, branch_id, **params)
      wrap(@connection.get(branch_path(project_id, branch_id, "databases"), query: params))
    end

    # @return [NeonAPI::Object]
    def database(project_id, branch_id, database_name)
      wrap(@connection.get(branch_path(project_id, branch_id, "databases/#{database_name}")))
    end

    # @param database [Hash] the "database" payload (e.g. { name:, owner_name: })
    # @return [NeonAPI::Object]
    def database_create(project_id, branch_id, database: {})
      wrap(@connection.post(branch_path(project_id, branch_id, "databases"), body: { database: database }))
    end

    # @return [NeonAPI::Object]
    def database_update(project_id, branch_id, database_name, database:)
      wrap(@connection.patch(branch_path(project_id, branch_id, "databases/#{database_name}"),
                             body: { database: database }))
    end

    # @return [NeonAPI::Object, nil]
    def database_delete(project_id, branch_id, database_name)
      wrap(@connection.delete(branch_path(project_id, branch_id, "databases/#{database_name}")))
    end

    # @!endgroup

    # @!group Endpoints (compute, project-scoped)

    # @return [NeonAPI::Object]
    def endpoints(project_id, **params)
      wrap(@connection.get("projects/#{project_id}/endpoints", query: params))
    end

    # @return [NeonAPI::Object]
    def endpoint(project_id, endpoint_id)
      wrap(@connection.get("projects/#{project_id}/endpoints/#{endpoint_id}"))
    end

    # @param endpoint [Hash] the "endpoint" payload (e.g. { branch_id:, type: })
    # @return [NeonAPI::Object]
    def endpoint_create(project_id, endpoint: {})
      wrap(@connection.post("projects/#{project_id}/endpoints", body: { endpoint: endpoint }))
    end

    # @return [NeonAPI::Object]
    def endpoint_update(project_id, endpoint_id, endpoint:)
      wrap(@connection.patch("projects/#{project_id}/endpoints/#{endpoint_id}", body: { endpoint: endpoint }))
    end

    # @return [NeonAPI::Object, nil]
    def endpoint_delete(project_id, endpoint_id)
      wrap(@connection.delete("projects/#{project_id}/endpoints/#{endpoint_id}"))
    end

    # Start a suspended endpoint. @return [NeonAPI::Object]
    def endpoint_start(project_id, endpoint_id)
      wrap(@connection.post("projects/#{project_id}/endpoints/#{endpoint_id}/start"))
    end

    # Suspend a running endpoint. @return [NeonAPI::Object]
    def endpoint_suspend(project_id, endpoint_id)
      wrap(@connection.post("projects/#{project_id}/endpoints/#{endpoint_id}/suspend"))
    end

    # @!endgroup

    # @!group Roles (branch-scoped)

    # @return [NeonAPI::Object]
    def roles(project_id, branch_id)
      wrap(@connection.get(branch_path(project_id, branch_id, "roles")))
    end

    # @return [NeonAPI::Object]
    def role(project_id, branch_id, role_name)
      wrap(@connection.get(branch_path(project_id, branch_id, "roles/#{role_name}")))
    end

    # @return [NeonAPI::Object]
    def role_create(project_id, branch_id, role_name)
      wrap(@connection.post(branch_path(project_id, branch_id, "roles"), body: { role: { name: role_name } }))
    end

    # @return [NeonAPI::Object, nil]
    def role_delete(project_id, branch_id, role_name)
      wrap(@connection.delete(branch_path(project_id, branch_id, "roles/#{role_name}")))
    end

    # Reset (rotate) a role's password. @return [NeonAPI::Object]
    def role_reset_password(project_id, branch_id, role_name)
      wrap(@connection.post(branch_path(project_id, branch_id, "roles/#{role_name}/reset_password")))
    end

    # Reveal a role's current password. @return [NeonAPI::Object]
    def role_reveal_password(project_id, branch_id, role_name)
      wrap(@connection.get(branch_path(project_id, branch_id, "roles/#{role_name}/reveal_password")))
    end

    # @!endgroup

    # @!group Operations & consumption

    # @return [NeonAPI::Object]
    def operations(project_id, **params)
      wrap(@connection.get("projects/#{project_id}/operations", query: params))
    end

    # @return [NeonAPI::Object]
    def operation(project_id, operation_id)
      wrap(@connection.get("projects/#{project_id}/operations/#{operation_id}"))
    end

    # Account-level consumption metrics. @return [NeonAPI::Object]
    def consumption_history_account(**params)
      wrap(@connection.get("consumption_history/account", query: params))
    end

    # Per-project consumption metrics. @return [NeonAPI::Object]
    def consumption_history_projects(**params)
      wrap(@connection.get("consumption_history/projects", query: params))
    end

    # A ready-to-use Postgres connection URI for a database + role.
    # @param database_name [String]
    # @param role_name [String]
    # @param params [Hash] extra query params (e.g. :branch_id, :endpoint_id, :pooled)
    # @return [NeonAPI::Object]
    def connection_uri(project_id, database_name:, role_name:, **params)
      query = { database_name: database_name, role_name: role_name }.merge(params)
      wrap(@connection.get("projects/#{project_id}/connection_uri", query: query))
    end

    # @!endgroup

    # @!group Pagination

    # Iterate every item of a cursor-paginated list endpoint, fetching pages as
    # needed. Returns an Enumerator when no block is given.
    #
    # @example
    #   client.paginate("projects", collection: "projects").map(&:id)
    #
    # @param path [String] the list endpoint path
    # @param collection [String] the response key holding the array (e.g. "projects")
    # @param params [Hash] query params forwarded to each page request
    # @yieldparam item [NeonAPI::Object]
    # @return [Enumerator, void]
    def paginate(path, collection:, **params)
      return enum_for(:paginate, path, collection: collection, **params) unless block_given?

      cursor = nil
      loop do
        page = @connection.get(path, query: params.merge(cursor: cursor).compact)
        items = Array(page[collection.to_s])
        items.each { |item| yield wrap(item) }
        next_cursor = page.dig("pagination", "cursor")
        break if items.empty? || next_cursor.nil? || next_cursor.to_s.empty? || next_cursor == cursor

        cursor = next_cursor
      end
    end

    # Enumerate all projects across pages.
    # @return [Enumerator, void]
    def each_project(**params, &block)
      paginate("projects", collection: "projects", **params, &block)
    end

    # Enumerate all operations for a project across pages.
    # @return [Enumerator, void]
    def each_operation(project_id, **params, &block)
      paginate("projects/#{project_id}/operations", collection: "operations", **params, &block)
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

    def branch_path(project_id, branch_id, suffix)
      "projects/#{project_id}/branches/#{branch_id}/#{suffix}"
    end

    def wrap(payload)
      payload.is_a?(::Hash) ? Object.new(payload) : payload
    end
  end
end
