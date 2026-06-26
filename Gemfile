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
end

# Optional: Ed25519 (EdDSA) support for verifying Neon Auth JWTs.
# Neon Auth signs tokens with EdDSA by default. Uncomment to enable local
# verification of those tokens with NeonAPI::Auth::JWTVerifier.
# gem "rbnacl", "~> 7.1"
