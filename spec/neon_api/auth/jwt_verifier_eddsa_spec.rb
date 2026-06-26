# frozen_string_literal: true

# End-to-end EdDSA (Ed25519) verification — the real signature path that genuine
# Neon Auth (Better Auth) tokens use. This is the regression guard for issue #1:
# jwt 3.x changed its Ed25519/OKP-JWK algorithm matching and raises
# JWT::IncorrectAlgorithm on real Neon tokens, but the rest of the suite stubs
# JWKS/decode and never exercises a real EdDSA signature, so it didn't catch it.
#
# Unlike jwt_verifier_spec.rb (which uses RS256 to stay dependency-free), this
# generates a real Ed25519 key, builds a Neon-shaped JWKS from it, signs a real
# token, and runs it through JWTVerifier with the real JWT.decode. EdDSA needs
# `rbnacl` + libsodium; when unavailable we skip rather than fail (CI installs
# libsodium so the guard always runs there).

eddsa_available =
  begin
    require "rbnacl"
    true
  rescue LoadError
    false
  end

RSpec.describe NeonAPI::Auth::JWTVerifier do
  subject(:verifier) do
    described_class.new(jwks_url: JWTHelpers::JWKS_URL, algorithms: %w[EdDSA RS256])
  end

  unless eddsa_available
    it "is skipped because rbnacl/libsodium is unavailable" do
      skip "EdDSA verification requires the `rbnacl` gem and libsodium at runtime"
    end
  end

  if eddsa_available
    it "verifies a real EdDSA token against an OKP/Ed25519 JWKS" do
      stub_jwks(eddsa_jwks_document)
      token = sign_token_eddsa(neon_claims("sub" => "9f1c2e7a-uuid"))

      claims = verifier.verify(token)

      expect(claims).to be_a(NeonAPI::Auth::Claims)
      expect(claims.sub).to eq("9f1c2e7a-uuid")
      expect(claims.email).to eq("ada@example.com")
      expect(claims.role).to eq("authenticated")
    end

    it "serves a Neon-shaped JWKS entry (kty OKP, crv Ed25519, alg EdDSA)" do
      key = eddsa_jwks_document[:keys].first
      expect(key).to include(kty: "OKP", crv: "Ed25519", alg: "EdDSA")
      expect(key[:x]).to be_a(String).and(satisfy { |x| !x.empty? })
    end

    it "rejects a token signed by a different Ed25519 key (bad signature)" do
      stub_jwks(eddsa_jwks_document) # JWKS advertises the legitimate key only
      attacker = JWT::JWK.new(RbNaCl::SigningKey.generate, kid: ed25519_jwk.kid)
      forged = JWT.encode(neon_claims, attacker.signing_key, "EdDSA", kid: ed25519_jwk.kid)

      expect { verifier.verify(forged) }.to raise_error(NeonAPI::Auth::InvalidTokenError)
      expect(verifier.verify?(forged)).to be_nil
    end

    it "rejects a tampered payload" do
      stub_jwks(eddsa_jwks_document)
      token = sign_token_eddsa(neon_claims)
      header, _payload, sig = token.split(".")
      forged_payload = JWT::Base64.url_encode(JSON.generate(neon_claims("role" => "admin")))
      tampered = [header, forged_payload, sig].join(".")

      expect(verifier.verify?(tampered)).to be_nil
    end

    it "raises TokenExpiredError for an expired EdDSA token" do
      stub_jwks(eddsa_jwks_document)
      token = sign_token_eddsa(neon_claims("exp" => Time.now.to_i - 60, "iat" => Time.now.to_i - 120))
      expect { verifier.verify(token) }.to raise_error(NeonAPI::Auth::TokenExpiredError)
    end
  end
end
