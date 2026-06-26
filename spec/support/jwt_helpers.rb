# frozen_string_literal: true

require "jwt"

# Helpers for exercising the JWT verifier without external services.
#
# We use RS256 here because it needs nothing beyond OpenSSL (already in stdlib),
# while exercising the exact same JWKS code path Neon Auth's EdDSA tokens use.
module JWTHelpers
  JWKS_URL = "https://example.neon-auth.dev/.well-known/jwks.json"

  # A reusable RSA key turned into a JWT::JWK with a stable kid.
  def rsa_jwk(kid: "test-key-1")
    @rsa_jwks ||= {}
    @rsa_jwks[kid] ||= JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048), kid: kid)
  end

  # The public JWKS document a project's jwks_url would serve.
  def jwks_document(*jwks)
    jwks = [rsa_jwk] if jwks.empty?
    { keys: jwks.map(&:export) }
  end

  # Sign a token with the given JWK using RS256.
  def sign_token(payload, jwk: rsa_jwk)
    JWT.encode(payload, jwk.signing_key, "RS256", kid: jwk.kid)
  end

  # Default valid Neon-Auth-shaped claims.
  def neon_claims(overrides = {})
    now = Time.now.to_i
    {
      "sub" => "user_abc123",
      "email" => "ada@example.com",
      "role" => "authenticated",
      "iat" => now,
      "exp" => now + 3600
    }.merge(overrides.transform_keys(&:to_s))
  end

  # Stub the JWKS endpoint to return the given document.
  def stub_jwks(document = jwks_document, url: JWKS_URL)
    stub_request(:get, url).to_return(
      status: 200,
      body: JSON.generate(document),
      headers: { "Content-Type" => "application/json" }
    )
  end
end

RSpec.configure do |config|
  config.include JWTHelpers
end
