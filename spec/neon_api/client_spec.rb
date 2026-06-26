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
    it "#me fetches the current user and wraps the response" do
      stub_neon(:get, "users/me", body: { email: "ada@example.com", id: "u1" })
      me = client.me
      expect(me).to be_a(NeonAPI::Object)
      expect(me.email).to eq("ada@example.com")
    end
  end

  describe "api keys" do
    it "#api_keys lists keys" do
      stub_neon(:get, "api_keys", body: { api_keys: [{ id: 1 }] })
      expect(client.api_keys.api_keys.first.id).to eq(1)
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

    it "#project fetches one" do
      stub_neon(:get, "projects/p1", body: { project: { id: "p1" } })
      expect(client.project("p1").project.id).to eq("p1")
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

  describe "#auth" do
    it "returns a branch-scoped Neon Auth resource" do
      auth = client.auth("p1", "b1")
      expect(auth).to be_a(NeonAPI::Auth::Branch)
      expect(auth.project_id).to eq("p1")
      expect(auth.branch_id).to eq("b1")
    end
  end
end
