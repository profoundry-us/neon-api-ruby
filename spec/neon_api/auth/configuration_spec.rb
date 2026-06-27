# frozen_string_literal: true

RSpec.describe NeonAPI::Auth::Configuration do
  # NeonAPI::Auth config is process-global; isolate every example.
  before { NeonAPI::Auth.reset! }
  after  { NeonAPI::Auth.reset! }

  let(:base_url) { "https://ep-x.neonauth.us-east-1.aws.neon.tech/neondb/auth" }

  describe "#jwks_url" do
    it "derives the JWKS URL from base_url" do
      config = described_class.new.tap { |c| c.base_url = base_url }
      expect(config.jwks_url).to eq("#{base_url}/.well-known/jwks.json")
    end

    it "honors an explicit jwks_url" do
      config = described_class.new.tap do |c|
        c.base_url = base_url
        c.jwks_url = "https://other/jwks.json"
      end
      expect(config.jwks_url).to eq("https://other/jwks.json")
    end

    it "is nil when base_url is unset" do
      expect(described_class.new.jwks_url).to be_nil
    end
  end

  describe "#enabled?" do
    it "defaults to true when base_url is present" do
      expect(described_class.new.tap { |c| c.base_url = base_url }.enabled?).to be(true)
    end

    it "defaults to false when base_url is absent" do
      expect(described_class.new.enabled?).to be(false)
    end

    it "honors an explicit override" do
      config = described_class.new.tap { |c| c.base_url = base_url }
      config.enabled = false
      expect(config.enabled?).to be(false)
    end
  end

  describe "#find_user / #resolve_user" do
    it "stores and invokes the identity hook with claims" do
      config = described_class.new
      config.find_user { |claims| "user:#{claims.sub}" }
      claims = NeonAPI::Auth::Claims.new("sub" => "u-1")
      expect(config.resolve_user(claims)).to eq("user:u-1")
    end

    it "raises when no identity hook is registered" do
      expect { described_class.new.resolve_user(double) }
        .to raise_error(NeonAPI::ConfigurationError, /identity hook is not set/)
    end
  end

  describe "builders" do
    let(:config) { described_class.new.tap { |c| c.base_url = base_url } }

    it "builds a JWTVerifier from the derived jwks_url" do
      expect(config.build_verifier).to be_a(NeonAPI::Auth::JWTVerifier)
    end

    it "forwards verifier_options" do
      config.verifier_options = { issuer: "https://iss" }
      verifier = config.build_verifier
      expect(verifier).to be_a(NeonAPI::Auth::JWTVerifier)
    end

    it "builds a SocialAuth and BetterAuthClient at the base_url" do
      expect(config.build_social).to be_a(NeonAPI::Auth::SocialAuth)
      expect(config.build_better_auth).to be_a(NeonAPI::Auth::BetterAuthClient)
      expect(config.build_social.base_url).to eq(base_url)
    end

    it "raises ConfigurationError when base_url is missing" do
      empty = described_class.new
      expect { empty.build_social }.to raise_error(NeonAPI::ConfigurationError, /base_url is not configured/)
      expect { empty.build_verifier }.to raise_error(NeonAPI::ConfigurationError, /not configured/)
    end
  end

  describe "NeonAPI::Auth module accessors" do
    it "configure yields the config and reports enabled?" do
      NeonAPI::Auth.configure { |c| c.base_url = base_url }
      expect(NeonAPI::Auth.enabled?).to be(true)
      expect(NeonAPI::Auth.config.base_url).to eq(base_url)
    end

    it "memoizes the read-only verifier" do
      NeonAPI::Auth.configure { |c| c.base_url = base_url }
      expect(NeonAPI::Auth.verifier).to equal(NeonAPI::Auth.verifier)
    end

    it "rebuilds the memoized verifier after reconfiguring" do
      NeonAPI::Auth.configure { |c| c.base_url = base_url }
      first = NeonAPI::Auth.verifier
      NeonAPI::Auth.configure { |c| c.base_url = "https://ep-y.neonauth.x.aws.neon.tech/neondb/auth" }
      expect(NeonAPI::Auth.verifier).not_to equal(first)
    end

    # Issue #6: the stateful clients carry a mutable cookie jar, so they must not
    # be shared across threads. They are built fresh per call.
    it "returns a fresh social / better_auth client each call" do
      NeonAPI::Auth.configure { |c| c.base_url = base_url }
      expect(NeonAPI::Auth.social).not_to equal(NeonAPI::Auth.social)
      expect(NeonAPI::Auth.better_auth).not_to equal(NeonAPI::Auth.better_auth)
      expect(NeonAPI::Auth.social.base_url).to eq(base_url)
    end

    it "isolates cookie jars across concurrent threads" do
      NeonAPI::Auth.configure { |c| c.base_url = base_url }

      readbacks = Array.new(12) do |i|
        Thread.new do
          client = NeonAPI::Auth.social
          client.cookies = { "sid" => "user-#{i}" }
          Thread.pass # invite interleaving; a shared jar would clobber here
          client.session_cookie
        end
      end.map(&:value)

      expect(readbacks.sort).to eq(Array.new(12) { |i| "sid=user-#{i}" }.sort)
    end

    it "delegates find_user to the configured hook" do
      NeonAPI::Auth.configure { |c| c.find_user { |claims| claims.sub.upcase } }
      expect(NeonAPI::Auth.find_user(NeonAPI::Auth::Claims.new("sub" => "abc"))).to eq("ABC")
    end
  end
end
