# frozen_string_literal: true

RSpec.describe NeonAPI::OmniAuth do
  let(:integration) do
    NeonAPI::Object.new(
      "base_url" => "https://auth.example",
      "jwks_url" => "https://auth.example/.well-known/jwks.json",
      "pub_client_key" => "pck_1"
    )
  end

  describe ".openid_connect_options" do
    subject(:options) do
      described_class.openid_connect_options(
        integration: integration,
        client_id: "cid",
        client_secret: "secret",
        redirect_uri: "https://app.example/auth/openid_connect/callback"
      )
    end

    it "names the strategy openid_connect by default" do
      expect(options[:name]).to eq(:openid_connect)
    end

    it "derives the issuer from the integration base_url" do
      expect(options[:issuer]).to eq("https://auth.example")
    end

    it "maps client credentials into client_options" do
      expect(options[:client_options]).to include(identifier: "cid", secret: "secret")
    end

    it "derives scheme, host, and port from the base url" do
      expect(options[:client_options]).to include(scheme: "https", host: "auth.example", port: 443)
    end

    it "builds the OIDC endpoint URLs" do
      co = options[:client_options]
      expect(co[:authorization_endpoint]).to eq("https://auth.example/authorize")
      expect(co[:token_endpoint]).to eq("https://auth.example/token")
      expect(co[:userinfo_endpoint]).to eq("https://auth.example/userinfo")
      expect(co[:jwks_uri]).to eq("https://auth.example/.well-known/jwks.json")
    end

    it "accepts a plain Hash integration" do
      opts = described_class.openid_connect_options(
        integration: { "base_url" => "https://h.example" },
        client_id: "c", client_secret: "s", redirect_uri: "https://app/cb"
      )
      expect(opts[:issuer]).to eq("https://h.example")
    end

    it "lets the caller override the issuer" do
      opts = described_class.openid_connect_options(
        integration: integration, client_id: "c", client_secret: "s",
        redirect_uri: "https://app/cb", issuer: "https://custom.example"
      )
      expect(opts[:issuer]).to eq("https://custom.example")
    end

    it "deep-merges arbitrary overrides" do
      opts = described_class.openid_connect_options(
        integration: integration, client_id: "c", client_secret: "s",
        redirect_uri: "https://app/cb",
        client_options: { connection_opts: { request: { timeout: 10 } } }
      )
      expect(opts[:client_options][:connection_opts]).to eq(request: { timeout: 10 })
      expect(opts[:client_options][:identifier]).to eq("c")
    end

    it "raises a clear error when base_url is missing" do
      expect do
        described_class.openid_connect_options(
          integration: { "jwks_url" => "x" }, client_id: "c",
          client_secret: "s", redirect_uri: "cb"
        )
      end.to raise_error(ArgumentError, /missing "base_url"/)
    end
  end

  describe ".jwks_url" do
    it "extracts the jwks_url" do
      expect(described_class.jwks_url(integration)).to eq("https://auth.example/.well-known/jwks.json")
    end

    it "raises when absent" do
      expect { described_class.jwks_url({ "base_url" => "x" }) }.to raise_error(ArgumentError)
    end
  end
end
