# frozen_string_literal: true

RSpec.describe NeonAPI::Auth::OAuthProviders do
  subject(:providers) { client.auth("p1", "b1").oauth_providers }

  let(:base) { "projects/p1/branches/b1/auth/oauth_providers" }

  describe "#list" do
    it "GETs the providers" do
      stub_neon(:get, base, body: { oauth_providers: [{ id: "google" }] })
      expect(providers.list.oauth_providers.first.id).to eq("google")
    end
  end

  describe "#add" do
    it "POSTs id and credentials" do
      stub = stub_neon(:post, base,
                       request_body: { id: "google", client_id: "cid", client_secret: "secret" },
                       body: { id: "google" })
      providers.add(id: "google", client_id: "cid", client_secret: "secret")
      expect(stub).to have_been_requested
    end

    it "omits nil credential fields (shared-keys mode)" do
      stub = stub_neon(:post, base, request_body: { id: "github" }, body: { id: "github" })
      providers.add(id: "github")
      expect(stub).to have_been_requested
    end

    it "passes microsoft_tenant_id when given" do
      stub = stub_neon(:post, base,
                       request_body: { id: "microsoft", microsoft_tenant_id: "tenant-1" },
                       body: {})
      providers.add(id: "microsoft", microsoft_tenant_id: "tenant-1")
      expect(stub).to have_been_requested
    end

    it "rejects unsupported provider ids before making a request" do
      expect { providers.add(id: "facebook") }.to raise_error(ArgumentError, /unsupported OAuth provider/)
      expect(a_request(:post, "#{APIHelpers::BASE_URL}/#{base}")).not_to have_been_made
    end
  end

  describe "#update" do
    it "PATCHes the specific provider" do
      stub = stub_neon(:patch, "#{base}/google",
                       request_body: { id: "google", client_secret: "rotated" },
                       body: { id: "google" })
      providers.update("google", client_secret: "rotated")
      expect(stub).to have_been_requested
    end
  end

  describe "#delete" do
    it "DELETEs the specific provider" do
      stub = stub_neon(:delete, "#{base}/google", body: {})
      providers.delete("google")
      expect(stub).to have_been_requested
    end

    it "validates the id" do
      expect { providers.delete("nope") }.to raise_error(ArgumentError)
    end
  end

  it "exposes the supported provider ids" do
    expect(described_class::SUPPORTED).to contain_exactly("google", "github", "microsoft", "vercel")
  end
end
