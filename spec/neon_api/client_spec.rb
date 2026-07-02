# frozen_string_literal: true

RSpec.describe NeonAPI::Client do
  describe "factories" do
    it ".from_environ reads NEON_API_KEY" do
      stub_const("ENV", ENV.to_hash.merge("NEON_API_KEY" => "from_env"))
      stub_request(:get, "https://console.neon.tech/api/v2/users/me").to_return(body: "{}")
      client = described_class.from_environ
      expect(client).to be_a(described_class)
    end

    it ".from_environ raises when the variable is unset" do
      stub_const("ENV", ENV.to_hash.except("NEON_API_KEY"))
      expect { described_class.from_environ }.to raise_error(NeonAPI::ConfigurationError, /NEON_API_KEY/)
    end

    it ".from_environ supports a custom variable name" do
      stub_const("ENV", ENV.to_hash.merge("MY_KEY" => "x"))
      expect(described_class.from_environ(env: "MY_KEY")).to be_a(described_class)
    end

    it ".from_token builds a client" do
      expect(described_class.from_token("tok")).to be_a(described_class)
    end
  end

  describe "account" do
    it "#me fetches the current user and wraps the response in the generated type" do
      stub_neon(:get, "users/me", body: { email: "ada@example.com", id: "u1" })
      me = client.me
      expect(me).to be_a(NeonAPI::Types::CurrentUserInfoResponse)
      expect(me.email).to eq("ada@example.com")
    end
  end

  describe "api keys" do
    it "#api_keys wraps each item of the bare-array response" do
      stub_neon(:get, "api_keys", body: [{ id: 1, name: "ci" }])
      keys = client.api_keys
      expect(keys.first).to be_a(NeonAPI::Types::ApiKeysListResponseItem)
      expect(keys.first.id).to eq(1)
    end

    it "#api_key_create posts a key name" do
      stub = stub_neon(:post, "api_keys", request_body: { key_name: "ci" }, body: { id: 7, key: "secret" })
      result = client.api_key_create("ci")
      expect(stub).to have_been_requested
      expect(result.key).to eq("secret")
    end

    it "#api_key_revoke deletes by id" do
      stub = stub_neon(:delete, "api_keys/7", body: { id: 7, revoked: true })
      client.api_key_revoke(7)
      expect(stub).to have_been_requested
    end
  end

  describe "projects" do
    it "#projects lists projects with query params" do
      stub = stub_neon(:get, "projects", query: { "limit" => "5" }, body: { projects: [] })
      client.projects(limit: 5)
      expect(stub).to have_been_requested
    end

    it "#project fetches one and types the nested project" do
      stub_neon(:get, "projects/p1", body: { project: { id: "p1" } })
      response = client.project("p1")
      expect(response).to be_a(NeonAPI::Types::ProjectResponse)
      expect(response.project).to be_a(NeonAPI::Types::Project)
      expect(response.project.id).to eq("p1")
    end

    it "#project_create wraps the payload under :project" do
      stub = stub_neon(:post, "projects", request_body: { project: { name: "Prod" } },
                                          body: { project: { id: "p9" } })
      client.project_create(project: { name: "Prod" })
      expect(stub).to have_been_requested
    end
  end

  describe "branches" do
    it "#branches lists branches for a project" do
      stub_neon(:get, "projects/p1/branches", body: { branches: [{ id: "b1" }] })
      expect(client.branches("p1").branches.first.id).to eq("b1")
    end
  end

  describe "databases" do
    it "#databases lists for a branch with typed items" do
      stub_neon(:get, "projects/p1/branches/b1/databases", body: { databases: [{ name: "neondb" }] })
      databases = client.databases("p1", "b1").databases
      expect(databases.first).to be_a(NeonAPI::Types::Database)
      expect(databases.first.name).to eq("neondb")
    end

    it "#database fetches one by name" do
      stub_neon(:get, "projects/p1/branches/b1/databases/neondb", body: { database: { name: "neondb" } })
      expect(client.database("p1", "b1", "neondb").database.name).to eq("neondb")
    end

    it "#database_create wraps the payload under :database" do
      stub = stub_neon(:post, "projects/p1/branches/b1/databases",
                       request_body: { database: { name: "app", owner_name: "neondb_owner" } },
                       body: { database: { name: "app" } })
      client.database_create("p1", "b1", database: { name: "app", owner_name: "neondb_owner" })
      expect(stub).to have_been_requested
    end

    it "#database_update PATCHes" do
      stub = stub_neon(:patch, "projects/p1/branches/b1/databases/app",
                       request_body: { database: { owner_name: "x" } }, body: { database: {} })
      client.database_update("p1", "b1", "app", database: { owner_name: "x" })
      expect(stub).to have_been_requested
    end

    it "#database_delete DELETEs" do
      stub = stub_neon(:delete, "projects/p1/branches/b1/databases/app", body: { database: {} })
      client.database_delete("p1", "b1", "app")
      expect(stub).to have_been_requested
    end
  end

  describe "endpoints" do
    it "#endpoints lists for a project" do
      stub_neon(:get, "projects/p1/endpoints", body: { endpoints: [{ id: "ep1" }] })
      expect(client.endpoints("p1").endpoints.first.id).to eq("ep1")
    end

    it "#endpoint_create wraps the payload under :endpoint" do
      stub = stub_neon(:post, "projects/p1/endpoints",
                       request_body: { endpoint: { branch_id: "b1", type: "read_write" } },
                       body: { endpoint: { id: "ep9" } })
      client.endpoint_create("p1", endpoint: { branch_id: "b1", type: "read_write" })
      expect(stub).to have_been_requested
    end

    it "#endpoint_start and #endpoint_suspend POST to the action paths" do
      start = stub_neon(:post, "projects/p1/endpoints/ep1/start", body: { endpoint: {} })
      suspend = stub_neon(:post, "projects/p1/endpoints/ep1/suspend", body: { endpoint: {} })
      client.endpoint_start("p1", "ep1")
      client.endpoint_suspend("p1", "ep1")
      expect(start).to have_been_requested
      expect(suspend).to have_been_requested
    end
  end

  describe "roles" do
    it "#roles lists for a branch" do
      stub_neon(:get, "projects/p1/branches/b1/roles", body: { roles: [{ name: "neondb_owner" }] })
      expect(client.roles("p1", "b1").roles.first.name).to eq("neondb_owner")
    end

    it "#role_create posts the role name under :role" do
      stub = stub_neon(:post, "projects/p1/branches/b1/roles",
                       request_body: { role: { name: "app" } }, body: { role: { name: "app" } })
      client.role_create("p1", "b1", "app")
      expect(stub).to have_been_requested
    end

    it "#role_reset_password POSTs to the reset path" do
      stub = stub_neon(:post, "projects/p1/branches/b1/roles/app/reset_password", body: { role: {} })
      client.role_reset_password("p1", "b1", "app")
      expect(stub).to have_been_requested
    end

    it "#role_reveal_password GETs the password" do
      stub_neon(:get, "projects/p1/branches/b1/roles/app/reveal_password", body: { password: "s3cret" })
      expect(client.role_reveal_password("p1", "b1", "app").password).to eq("s3cret")
    end
  end

  describe "operations & consumption" do
    it "#operations lists for a project" do
      stub_neon(:get, "projects/p1/operations", body: { operations: [{ id: "op1" }] })
      expect(client.operations("p1").operations.first.id).to eq("op1")
    end

    it "#operation fetches one" do
      stub_neon(:get, "projects/p1/operations/op1", body: { operation: { id: "op1" } })
      expect(client.operation("p1", "op1").operation.id).to eq("op1")
    end

    it "#consumption_history_account forwards query params" do
      stub = stub_neon(:get, "consumption_history/account", query: { "granularity" => "daily" },
                                                            body: { periods: [] })
      client.consumption_history_account(granularity: "daily")
      expect(stub).to have_been_requested
    end

    it "#connection_uri requires database_name and role_name" do
      stub = stub_neon(:get, "projects/p1/connection_uri",
                       query: { "database_name" => "neondb", "role_name" => "neondb_owner", "pooled" => "true" },
                       body: { uri: "postgresql://..." })
      expect(client.connection_uri("p1", database_name: "neondb", role_name: "neondb_owner", pooled: true).uri)
        .to start_with("postgresql://")
      expect(stub).to have_been_requested
    end
  end

  describe "pagination" do
    it "#paginate follows the cursor across pages" do
      json = ->(h) { { status: 200, headers: { "Content-Type" => "application/json" }, body: JSON.generate(h) } }
      # First page (no cursor) declared first; the cursor page is declared last so
      # it takes precedence for the cursor=c1 request (WebMock: last match wins).
      stub_request(:get, "#{APIHelpers::BASE_URL}/projects")
        .to_return(json.call(projects: [{ id: "p1" }], pagination: { cursor: "c1" }))
      stub_request(:get, "#{APIHelpers::BASE_URL}/projects").with(query: { "cursor" => "c1" })
                                                            .to_return(json.call(projects: [{ id: "p2" }], pagination: {}))

      items = client.each_project.to_a
      expect(items.map(&:id)).to eq(%w[p1 p2])
      expect(items).to all(be_a(NeonAPI::Types::ProjectListItem))
    end

    it "#paginate returns an Enumerator without a block" do
      expect(client.paginate("projects", collection: "projects")).to be_a(Enumerator)
    end
  end

  describe "#auth" do
    it "returns a branch-scoped Neon Auth resource" do
      auth = client.auth("p1", "b1")
      expect(auth).to be_a(NeonAPI::Auth::Branch)
      expect(auth.project_id).to eq("p1")
      expect(auth.branch_id).to eq("b1")
    end
  end
end
