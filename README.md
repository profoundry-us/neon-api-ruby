# neon-api-ruby

A Ruby client for the [Neon](https://neon.tech) API, with **first-class
[Neon Auth](https://neon.com/docs/auth/overview) support** for Ruby on Rails apps.

This is the Ruby counterpart to the official
[`neon-api-python`](https://github.com/neondatabase/neon-api-python) client. It
mirrors that library's management API surface (projects, branches, API keys, …)
and goes further by wrapping the **Neon Auth** endpoints — enabling the
integration, configuring OAuth providers, managing users, and verifying Neon
Auth JWTs at runtime — so you can drop Neon Auth into a Rails app, including via
[OmniAuth](https://github.com/omniauth/omniauth).

> **Status:** `0.1.0`. The authentication surface is the priority and is
> implemented and tested; the broader management API is being filled in to stay
> in sync with the [Neon OpenAPI spec](https://api-docs.neon.tech/).

---

## Table of contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [Authentication & security](#authentication--security)
- [Neon Auth](#neon-auth)
  - [Enable the integration](#enable-the-integration)
  - [Configure OAuth providers](#configure-oauth-providers)
  - [Manage users](#manage-users)
  - [Verify JWTs at runtime](#verify-jwts-at-runtime)
- [Rails + OmniAuth](#rails--omniauth)
- [Management API](#management-api)
- [Error handling](#error-handling)
- [Calling endpoints that aren't wrapped yet](#calling-endpoints-that-arent-wrapped-yet)
- [Development](#development)
- [Roadmap](#roadmap)
- [License](#license)

---

## Installation

Add it to your `Gemfile`:

```ruby
gem "neon-api"
```

Then:

```bash
bundle install
```

Or install it directly:

```bash
gem install neon-api
```

> **Ed25519 / EdDSA note:** Neon Auth signs JWTs with EdDSA (Ed25519) by default.
> To verify those tokens locally with [`NeonAPI::Auth::JWTVerifier`](#verify-jwts-at-runtime),
> add the `rbnacl` gem (which the `jwt` gem uses for Ed25519):
>
> ```ruby
> gem "rbnacl", "~> 7.1"
> ```
>
> Projects configured for RS256 need no extra dependency.

## Quick start

```ruby
require "neon_api"

# Reads NEON_API_KEY from the environment
client = NeonAPI.from_environ

# ...or pass a key explicitly
client = NeonAPI.new(api_key: "neon_api_key_...")

client.me.email          #=> "you@example.com"
client.projects.projects #=> [#<NeonAPI::Object ...>, ...]
```

Every response is a [`NeonAPI::Object`](lib/neon_api/object.rb) — a thin wrapper
that supports both `obj["key"]` and `obj.key` access, and `to_h` for the raw
hash.

## Authentication & security

The client authenticates to the Neon API with a **Neon API key**, sent as a
bearer token. Your API key grants access to sensitive data — never commit it to
source control or expose it client-side. Prefer an environment variable:

```ruby
client = NeonAPI.from_environ              # reads NEON_API_KEY
client = NeonAPI.from_environ(env: "MY_KEY")
```

Create a key in the Neon Console under **Account settings → API keys**.

## Neon Auth

[Neon Auth](https://neon.com/docs/auth/overview) is Neon's managed
authentication. It issues standards-based JWTs, syncs users into your database,
and supports OAuth providers (Google, GitHub, Microsoft, Vercel). Integrations
are scoped to a **project + branch** — most apps use the project's default
branch.

Get the auth surface for a branch:

```ruby
auth = client.auth(project_id, branch_id)
```

### Enable the integration

```ruby
integration = auth.enable(auth_provider: "better_auth")

integration.jwks_url          #=> "https://.../.well-known/jwks.json"
integration.pub_client_key    #=> publishable client key (safe for the frontend)
integration.secret_server_key #=> SECRET — store securely, shown only once
integration.schema_name       #=> "neon_auth"
integration.table_name        #=> "users_sync"
integration.base_url          #=> hosted auth base URL
```

Inspect or update it later:

```ruby
auth.config                 # GET current configuration
auth.update(name: "My App") # PATCH settings
auth.disable                # remove the integration (keeps synced data)
auth.disable(delete_data: true)
```

### Configure OAuth providers

This is what you wire into Rails OmniAuth. Configure a provider with **your own**
OAuth credentials (in production — omit them to use Neon's shared dev keys):

```ruby
providers = auth.oauth_providers

providers.add(id: "google", client_id: ENV["GOOGLE_CLIENT_ID"],
                            client_secret: ENV["GOOGLE_CLIENT_SECRET"])
providers.add(id: "github", client_id: "...", client_secret: "...")

providers.list                                   # all configured providers
providers.update("google", client_secret: "...") # rotate a secret
providers.delete("github")
```

Supported provider ids: `google`, `github`, `microsoft`, `vercel`
(`NeonAPI::Auth::OAuthProviders::SUPPORTED`). Microsoft accepts an optional
`microsoft_tenant_id:`.

### Manage users

```ruby
users = auth.users

users.create(email: "ada@example.com", password: "s3cret", display_name: "Ada")
users.set_role(user_id, role: "admin")
users.update(user_id, display_name: "Ada L.")
users.delete(user_id)
```

Neon Auth also syncs users into `neon_auth.users_sync` in your database, so for
reads you can query that table directly from Rails.

### Verify JWTs at runtime

Your Rails app receives a Neon Auth JWT (typically in `Authorization: Bearer
<token>`) and verifies it against the project's JWKS endpoint:

```ruby
verifier = NeonAPI::Auth::JWTVerifier.new(jwks_url: ENV.fetch("NEON_AUTH_JWKS_URL"))
# or derive it from the integration:
verifier = auth.jwt_verifier(jwks_url: integration.jwks_url)

claims = verifier.verify(token)
claims.sub    #=> Neon Auth user id (matches neon_auth.users_sync.id)
claims.email
claims.role   #=> "authenticated"
```

The verifier checks the signature, expiry, and (optionally) issuer/audience;
caches the JWKS; and automatically refreshes once on key rotation. It raises
`NeonAPI::Auth::TokenExpiredError` / `NeonAPI::Auth::InvalidTokenError` on
failure, or use `verify?` to get `nil` instead:

```ruby
if (claims = verifier.verify?(token))
  current_user = User.find_by(neon_auth_id: claims.sub)
end
```

See [docs/neon_auth.md](docs/neon_auth.md) for the full reference.

## Rails + OmniAuth

Neon Auth's JWKS + hosted endpoints map cleanly onto the
[`omniauth_openid_connect`](https://github.com/omniauth/omniauth_openid_connect)
strategy. `NeonAPI::OmniAuth` turns an integration into the options hash that
strategy expects:

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect, NeonAPI::OmniAuth.openid_connect_options(
    integration: NEON_AUTH_INTEGRATION,   # the enable/config response (cached)
    client_id: ENV.fetch("NEON_AUTH_CLIENT_ID"),
    client_secret: ENV.fetch("NEON_AUTH_CLIENT_SECRET"),
    redirect_uri: "https://app.example.com/auth/openid_connect/callback"
  )
end
```

The full walkthrough — controller, session, and JWT-protected API requests — is
in [docs/rails_omniauth.md](docs/rails_omniauth.md).

## Management API

Mirrors the Python client. Currently wrapped:

```ruby
client.me

client.api_keys
client.api_key_create("ci")
client.api_key_revoke(key_id)

client.projects(limit: 10)
client.project(project_id)
client.project_create(project: { name: "Prod" })
client.project_update(project_id, project: { name: "Prod 2" })
client.project_delete(project_id)

client.branches(project_id)
client.branch(project_id, branch_id)
client.branch_create(project_id, branch: { name: "feature-x" })
```

More endpoints (databases, endpoints, roles, operations, consumption) are on the
[roadmap](#roadmap). Until they're wrapped, see below.

## Error handling

Non-2xx responses raise a subclass of `NeonAPI::APIError`, so you can rescue
broadly or specifically:

```ruby
begin
  client.project("does-not-exist")
rescue NeonAPI::NotFoundError => e
  e.status     #=> 404
  e.body       #=> parsed error body
  e.request    #=> "GET /projects/does-not-exist"
  e.request_id #=> Neon's request id, handy for support
end
```

| Status | Error class |
| ------ | ----------- |
| 400 | `NeonAPI::BadRequestError` |
| 401 | `NeonAPI::AuthenticationError` |
| 403 | `NeonAPI::ForbiddenError` |
| 404 | `NeonAPI::NotFoundError` |
| 409 | `NeonAPI::ConflictError` |
| 422 | `NeonAPI::UnprocessableEntityError` |
| 429 | `NeonAPI::RateLimitError` |
| 5xx | `NeonAPI::ServerError` |

All inherit from `NeonAPI::APIError < NeonAPI::Error`.

## Calling endpoints that aren't wrapped yet

The underlying connection is public, so you can reach any endpoint:

```ruby
client.connection.get("projects/#{id}/operations")
client.connection.post("projects/#{id}/branches/#{bid}/auth/send_test_email")
```

## Development

On the host (needs a local Ruby toolchain):

```bash
bin/setup            # or: bundle install
bundle exec rspec    # run the tests (fully mocked, no network)
bundle exec rubocop  # lint
bundle exec rake     # both
```

Or do everything in Docker — no system Ruby required, just Docker and
[`just`](https://github.com/casey/just):

```bash
just up      # build the image and start the container
just test    # run the tests
just lint    # run RuboCop
just check   # spec + rubocop (the default rake task)
just console # IRB with the gem loaded
```

See [docs/docker.md](docs/docker.md) for the full command list and notes.

Tests use [WebMock](https://github.com/bblimke/webmock) so they never touch the
network — the equivalent of the Python client's VCR cassettes.

## Roadmap

- [x] Authenticated client foundation (`from_environ` / `from_token`)
- [x] Neon Auth: enable / config / update / disable
- [x] Neon Auth: OAuth providers CRUD
- [x] Neon Auth: users
- [x] Runtime JWT verification (JWKS, caching, rotation)
- [x] OmniAuth / OIDC config helper
- [x] Management: me, api keys, projects, branches
- [ ] Management: databases, endpoints, roles, operations, consumption
- [ ] Generated schema/type objects from the OpenAPI spec
- [ ] Published to RubyGems

## License

[Apache-2.0](LICENSE), matching the upstream `neon-api-python` client.

This is an independent, community-built client and is not an official Neon
product.
