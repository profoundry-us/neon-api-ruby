# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **OpenAPI-generated response types** (`NeonAPI::Types`): every client method
  now returns a typed subclass of `NeonAPI::Object` generated from Neon's
  published OpenAPI spec — documented, YARD-typed readers for all known fields
  (including nested `$ref`s, arrays, and merged `allOf` schemas), while dynamic
  access to unknown/newer fields keeps working. Regenerate with
  `rake types:generate` (`lib/neon_api/type_generator.rb` is the dev-only
  generator; `lib/neon_api/types.rb` is committed). Cursor pagination yields
  typed items too (`each_project` → `Types::ProjectListItem`).
- **Management API completion**: `databases`, `endpoints` (incl. `start` /
  `suspend`), `roles` (incl. `reset_password` / `reveal_password`), `operations`,
  `consumption_history_account` / `_projects`, and `connection_uri`. Plus a
  cursor-paginating `#paginate` (with `#each_project` / `#each_operation`).
- **Automatic retries** in the HTTP layer: exponential backoff with full jitter
  on `429` (any method, honoring `Retry-After`) and transient `5xx`/network
  errors (idempotent methods only). Configurable via `max_retries` /
  `retry_max_delay`; `NeonAPI::APIError#retry_after` exposes the parsed header.
- **Instrumentation hook**: each request emits a `"request.neon_api"` event with
  `method`/`path`/`status`/`attempts` to any `ActiveSupport::Notifications`-style
  instrumenter (no-op by default). `Client.new` now forwards options to
  `Connection`.

- **Optional Rails layer** so apps stop hand-rolling the glue (#5):
  - `NeonAPI::Auth.configure` with a `Configuration` object and memoized,
    derived accessors — `enabled?`, `verifier`, `social`, `better_auth` — plus a
    single identity hook, `config.find_user { |claims| ... }`.
  - `NeonAPI::Auth::Controller`, a plain-Ruby controller concern
    (`neon_social_start` / `neon_social_callback`) that keeps flash, route
    helpers, and a request-derived `callback_url` in your own controller, with
    overridable `neon_social` / `neon_verifier` seams for request specs.
  - A `Railtie` (loaded only under Rails; defaults Neon Auth off in the test
    env) and a `rails g neon_auth:install` generator (initializer +
    `neon_auth_id` migration). The core gem stays framework-agnostic.
- **`NeonAPI::Auth::SocialAuth`** (and `auth.social`) — server-side social
  (OAuth) sign-in for managed Neon Auth ("Continue with Google"), with no Node
  sidecar or client-side JS. `#sign_in` initiates the provider flow and returns
  the redirect URL plus the challenge to stash; `#redeem_callback` exchanges the
  one-time `neon_auth_session_verifier` (+ challenge) for the session and an
  EdDSA JWT. Verified end-to-end against a live project; needs no
  `NEON_AUTH_COOKIE_SECRET` or project secret (#4).
- `NeonAPI::Auth::RestClient` base class extracted from `BetterAuthClient` and
  shared with `SocialAuth` (HTTP, Origin header, cookie jar, error mapping).
- **`NeonAPI::Auth::RackHandler`** — an optional Rack-mountable handler that
  serves the social `start` + `callback` routes (mirrors Neon's
  `createNeonAuth().handler()`); you provide a block mapping the verified claims
  to a local user. `rack` is loaded lazily and is not a runtime dependency (#4).
- **`NeonAPI::Auth::BetterAuthClient`** (and `auth.better_auth`) — a server-side
  wrapper around Neon Auth's Better Auth REST API (`sign_up_email`,
  `sign_in_email`, `get_session`, `token`, `sign_out`), with automatic `Origin`
  handling and a cookie jar. This is the supported path for server-rendered Rails
  sign-in, since managed Neon Auth is not an OIDC provider (#2).
- Offline EdDSA (Ed25519) verification spec exercising a real key, a Neon-shaped
  OKP JWKS, and the real `JWT.decode` — the regression guard for the jwt 3.x bug.

### Changed

- Endpoints that return a bare JSON array (`Client#api_keys`) now wrap each
  element (`Types::ApiKeysListResponseItem`) instead of returning raw hashes,
  matching the rest of the client.
- Pinned `jwt` to `~> 2.7` (was `>= 2.7, < 4.0`). jwt 3.x rejects genuine Neon
  Auth EdDSA tokens with `JWT::IncorrectAlgorithm` (#1).
- Documentation now references `neon_auth.user` (Better Auth's native table),
  not the legacy `neon_auth.users_sync` name, and clarifies that `config` returns
  a subset of `enable`'s fields (#3).
- `NeonAPI::OmniAuth.openid_connect_options` is documented as **not** working
  against managed Neon Auth (no OIDC endpoints); it remains for self-hosted
  Better Auth with the oidc-provider plugin or another real OIDC provider (#2).

### Fixed

- Real EdDSA token verification now works out of the box via the `jwt` 2.x pin
  (#1).
- **Thread-safety:** `NeonAPI::Auth.social` / `.better_auth` no longer memoize a
  single shared client. Those clients carry a mutable cookie jar, so a shared
  instance could race across threads and cross sessions between users under a
  threaded server (Puma). They now return a fresh client per call; the
  `Controller` concern builds one per request. `.verifier` stays memoized
  (read-only) (#6).

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
