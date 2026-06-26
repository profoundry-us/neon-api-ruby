# frozen_string_literal: true

require_relative "lib/neon_api/version"

Gem::Specification.new do |spec|
  spec.name        = "neon-api"
  spec.version     = NeonAPI::VERSION
  spec.authors     = ["Topher Fangio"]
  spec.email       = ["topher@profoundry.us"]

  spec.summary     = "Ruby client for the Neon API, with first-class Neon Auth support."
  spec.description = <<~DESC
    A Ruby wrapper for the Neon (neon.tech) API. It focuses first on Neon Auth —
    enabling the integration, configuring OAuth providers, managing users, and
    verifying Neon Auth JWTs at runtime — so you can wire Neon Auth into a Ruby on
    Rails app (including via OmniAuth). The management API surface (projects,
    branches, endpoints, roles, ...) is included and kept in sync with the Neon
    OpenAPI specification.
  DESC

  spec.homepage = "https://github.com/profoundry-us/neon-api-ruby"
  spec.license  = "Apache-2.0"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = spec.homepage
  spec.metadata["changelog_uri"]     = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"]   = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}#readme"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    "docs/**/*.md"
  ]
  spec.require_paths = ["lib"]

  # Runtime dependencies are kept intentionally minimal. The core HTTP client
  # relies only on the Ruby standard library (net/http, json, openssl).
  #
  # JWT verification (NeonAPI::Auth::JWTVerifier) needs the `jwt` gem. Neon Auth
  # signs tokens with EdDSA (Ed25519) by default, which the `jwt` gem supports
  # when `rbnacl` is present; RS256 projects need no extra dependency.
  spec.add_dependency "jwt", ">= 2.7", "< 4.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.20"
end
