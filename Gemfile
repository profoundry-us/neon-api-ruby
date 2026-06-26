# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in neon-api.gemspec
gemspec

group :development, :test do
  gem "rake"
  gem "rspec"
  gem "rubocop"
  gem "rubocop-rspec"
  gem "webmock"

  # Loads .env (local only, never in CI) so the opt-in live integration spec has
  # a stable target via NEON_PROJECT_ID/NEON_BRANCH_ID. See .env.example.
  gem "dotenv"

  # Exercises the optional Rack-mountable social handler. `rack` is loaded lazily
  # by NeonAPI::Auth::RackHandler and is not a runtime dependency of the gem.
  gem "rack"

  # Ed25519 (EdDSA) support so the test suite can exercise real Neon Auth-shaped
  # token verification (see spec/neon_api/auth/jwt_verifier_eddsa_spec.rb).
  # Requires libsodium present at runtime. Apps verifying EdDSA tokens add this
  # to their own Gemfile; it is not a runtime dependency of the gem itself.
  gem "rbnacl", "~> 7.1"
end
