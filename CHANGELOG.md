# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-25

Initial release. Focus is on the Neon Auth surface for Ruby on Rails apps.

### Added

- Authenticated client foundation: `NeonAPI.new`, `NeonAPI.from_environ`
  (`NEON_API_KEY`), and `NeonAPI.from_token`.
- HTTP layer built on the Ruby standard library (no third-party HTTP gem):
  bearer auth, JSON encode/decode, timeouts, and a structured error hierarchy
  (`NeonAPI::APIError` and per-status subclasses).
- `NeonAPI::Object` response wrapper supporting hash- and method-style access.
- **Neon Auth** (`client.auth(project_id, branch_id)`):
  - Integration lifecycle: `enable`, `config`, `update`, `disable`.
  - OAuth providers CRUD (`google`, `github`, `microsoft`, `vercel`).
  - User management (`create`, `update`, `set_role`, `delete`).
- **`NeonAPI::Auth::JWTVerifier`** — runtime JWT verification against a project's
  JWKS, with caching, automatic refresh on key rotation, optional issuer/audience
  checks, and EdDSA/RS256 support.
- **`NeonAPI::OmniAuth`** — turns a Neon Auth integration into options for the
  `omniauth_openid_connect` strategy.
- Management API: `me`, API keys, projects, and branches.
- Full RSpec suite (mocked with WebMock — no network access) and RuboCop config.
- Documentation: README, `docs/neon_auth.md`, `docs/rails_omniauth.md`.

[Unreleased]: https://github.com/profoundry-us/neon-api-ruby/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/profoundry-us/neon-api-ruby/releases/tag/v0.1.0
