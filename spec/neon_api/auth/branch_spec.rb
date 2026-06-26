# frozen_string_literal: true

RSpec.describe NeonAPI::Auth::Branch do
  subject(:auth) { client.auth("p1", "b1") }

  let(:base) { "projects/p1/branches/b1/auth" }

  describe "#enable" do
    it "POSTs the auth provider and returns the integration credentials" do
      stub = stub_neon(:post, base,
                       request_body: { auth_provider: "better_auth" },
                       body: {
                         auth_provider: "better_auth",
                         pub_client_key: "pck_1",
                         secret_server_key: "ssk_1",
                         jwks_url: "https://auth.example/.well-known/jwks.json",
                         schema_name: "neon_auth",
                         table_name: "users_sync",
                         base_url: "https://auth.example"
                       })

      integration = auth.enable
      expect(stub).to have_been_requested
      expect(integration.jwks_url).to eq("https://auth.example/.well-known/jwks.json")
      expect(integration.pub_client_key).to eq("pck_1")
    end

    it "includes database_name when provided" do
      stub = stub_neon(:post, base,
                       request_body: { auth_provider: "stack", database_name: "neondb" },
                       body: {})
      auth.enable(auth_provider: "stack", database_name: "neondb")
      expect(stub).to have_been_requested
    end
  end

  describe "#config" do
    it "GETs the current configuration" do
      stub_neon(:get, base, body: { auth_provider: "better_auth", base_url: "https://auth.example" })
      expect(auth.config.base_url).to eq("https://auth.example")
    end
  end

  describe "#update" do
    it "PATCHes the config endpoint" do
      stub = stub_neon(:patch, "#{base}/config", request_body: { name: "My App" }, body: { name: "My App" })
      auth.update(name: "My App")
      expect(stub).to have_been_requested
    end
  end

  describe "#disable" do
    it "DELETEs with delete_data: false by default" do
      stub = stub_neon(:delete, base, request_body: { delete_data: false }, body: {})
      auth.disable
      expect(stub).to have_been_requested
    end

    it "passes delete_data: true through" do
      stub = stub_neon(:delete, base, request_body: { delete_data: true }, body: {})
      auth.disable(delete_data: true)
      expect(stub).to have_been_requested
    end
  end

  describe "accessors" do
    it "#oauth_providers is memoized" do
      expect(auth.oauth_providers).to be_a(NeonAPI::Auth::OAuthProviders)
      expect(auth.oauth_providers).to equal(auth.oauth_providers)
    end

    it "#users is memoized" do
      expect(auth.users).to be_a(NeonAPI::Auth::Users)
      expect(auth.users).to equal(auth.users)
    end
  end

  describe "#jwt_verifier" do
    it "builds a verifier from an explicit jwks_url without calling the API" do
      verifier = auth.jwt_verifier(jwks_url: "https://auth.example/jwks.json")
      expect(verifier).to be_a(NeonAPI::Auth::JWTVerifier)
      expect(a_request(:get, "#{APIHelpers::BASE_URL}/#{base}")).not_to have_been_made
    end

    it "fetches the jwks_url from config when not given one" do
      stub_neon(:get, base, body: { jwks_url: "https://auth.example/jwks.json" })
      verifier = auth.jwt_verifier
      expect(verifier).to be_a(NeonAPI::Auth::JWTVerifier)
    end
  end
end
