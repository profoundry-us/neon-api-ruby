# frozen_string_literal: true

RSpec.describe NeonAPI::Auth::JWTVerifier do
  subject(:verifier) do
    described_class.new(jwks_url: JWTHelpers::JWKS_URL, algorithms: %w[RS256])
  end

  describe "#initialize" do
    it "requires a jwks_url" do
      expect { described_class.new(jwks_url: nil) }.to raise_error(ArgumentError)
      expect { described_class.new(jwks_url: "") }.to raise_error(ArgumentError)
    end
  end

  describe "#verify" do
    it "verifies a valid token against the JWKS and returns Claims" do
      stub_jwks
      token = sign_token(neon_claims)

      claims = verifier.verify(token)

      expect(claims).to be_a(NeonAPI::Auth::Claims)
      expect(claims.sub).to eq("user_abc123")
      expect(claims.user_id).to eq("user_abc123")
      expect(claims.email).to eq("ada@example.com")
      expect(claims.role).to eq("authenticated")
      expect(claims["email"]).to eq("ada@example.com")
    end

    it "exposes timestamp claims as Time objects" do
      stub_jwks
      claims = verifier.verify(sign_token(neon_claims))
      expect(claims.expires_at).to be_a(Time)
      expect(claims.issued_at).to be_a(Time)
    end

    it "caches the JWKS across verifications (one fetch)" do
      stub = stub_jwks
      3.times { verifier.verify(sign_token(neon_claims)) }
      expect(stub).to have_been_requested.once
    end

    it "raises TokenExpiredError for an expired token" do
      stub_jwks
      token = sign_token(neon_claims("exp" => Time.now.to_i - 60, "iat" => Time.now.to_i - 120))
      expect { verifier.verify(token) }.to raise_error(NeonAPI::Auth::TokenExpiredError)
    end

    it "honors leeway for slightly-expired tokens" do
      stub_jwks
      tolerant = described_class.new(jwks_url: JWTHelpers::JWKS_URL, algorithms: %w[RS256], leeway: 120)
      token = sign_token(neon_claims("exp" => Time.now.to_i - 30))
      expect { tolerant.verify(token) }.not_to raise_error
    end

    it "raises InvalidTokenError for a bad signature" do
      stub_jwks
      other_key = JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048), kid: rsa_jwk.kid)
      forged = JWT.encode(neon_claims, other_key.signing_key, "RS256", kid: rsa_jwk.kid)
      expect { verifier.verify(forged) }.to raise_error(NeonAPI::Auth::InvalidTokenError)
    end

    it "raises InvalidTokenError for a malformed token" do
      stub_jwks
      expect { verifier.verify("not.a.jwt") }.to raise_error(NeonAPI::Auth::InvalidTokenError)
    end

    it "raises InvalidTokenError for an empty token" do
      expect { verifier.verify("") }.to raise_error(NeonAPI::Auth::InvalidTokenError, /empty/)
    end

    it "verifies the issuer when configured" do
      stub_jwks
      strict = described_class.new(jwks_url: JWTHelpers::JWKS_URL, algorithms: %w[RS256],
                                   issuer: "https://auth.example")
      good = sign_token(neon_claims("iss" => "https://auth.example"))
      bad = sign_token(neon_claims("iss" => "https://evil.example"))
      expect(strict.verify(good).sub).to eq("user_abc123")
      expect { strict.verify(bad) }.to raise_error(NeonAPI::Auth::InvalidTokenError)
    end

    it "verifies the audience when configured" do
      stub_jwks
      strict = described_class.new(jwks_url: JWTHelpers::JWKS_URL, algorithms: %w[RS256],
                                   audience: "my-app")
      good = sign_token(neon_claims("aud" => "my-app"))
      bad = sign_token(neon_claims("aud" => "other-app"))
      expect(strict.verify(good).sub).to eq("user_abc123")
      expect { strict.verify(bad) }.to raise_error(NeonAPI::Auth::InvalidTokenError)
    end

    it "refreshes the JWKS once when it sees an unknown kid (key rotation)" do
      old_key = rsa_jwk(kid: "old")
      new_key = rsa_jwk(kid: "new")

      # First the endpoint serves only the old key, then (after rotation) both.
      stub_request(:get, JWTHelpers::JWKS_URL)
        .to_return({ status: 200, body: JSON.generate(jwks_document(old_key)) },
                   { status: 200, body: JSON.generate(jwks_document(old_key, new_key)) })

      # Warm the cache with a token from the old key.
      expect(verifier.verify(sign_token(neon_claims, jwk: old_key)).sub).to eq("user_abc123")

      # A token signed by the rotated-in key triggers a refresh and then verifies.
      token = sign_token(neon_claims, jwk: new_key)
      expect(verifier.verify(token).sub).to eq("user_abc123")
      expect(a_request(:get, JWTHelpers::JWKS_URL)).to have_been_made.twice
    end

    it "raises InvalidTokenError when the JWKS endpoint is unreachable" do
      stub_request(:get, JWTHelpers::JWKS_URL).to_return(status: 500, body: "oops")
      expect { verifier.verify(sign_token(neon_claims)) }
        .to raise_error(NeonAPI::Auth::InvalidTokenError, /failed to fetch JWKS/)
    end
  end

  describe "#verify?" do
    it "returns Claims on success" do
      stub_jwks
      expect(verifier.verify?(sign_token(neon_claims))).to be_a(NeonAPI::Auth::Claims)
    end

    it "returns nil instead of raising on failure" do
      stub_jwks
      expect(verifier.verify?("not.a.jwt")).to be_nil
    end
  end

  describe "#reset_cache!" do
    it "forces a re-fetch on the next verification" do
      stub = stub_jwks
      verifier.verify(sign_token(neon_claims))
      verifier.reset_cache!
      verifier.verify(sign_token(neon_claims))
      expect(stub).to have_been_requested.twice
    end
  end
end
