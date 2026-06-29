# neon-api-ruby

A Ruby client for the [Neon](https://neon.tech) API, with **first-class
[Neon Auth](https://neon.com/docs/auth/overview) support** for Ruby on Rails apps.

This is the Ruby counterpart to the official
[`neon-api-python`](https://github.com/neondatabase/neon-api-python) client. It
mirrors that library's management API surface (projects, branches, API keys, …)
and goes further by wrapping the **Neon Auth** endpoints — enabling the
integration, configuring OAuth providers, managing users, signing users in
server-side, and verifying Neon Auth JWTs at runtime — so you can drop Neon Auth
into a Rails app.

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
- [Rails sign-in (server-side)](#rails-sign-in-server-side)
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
integration.base_url          #=> hosted auth base URL
```

> `pub_client_key`, `secret_server_key`, `schema_name`, and `table_name` are
> returned by `enable` only — `auth.config` returns a smaller set (no keys, no
> schema/table). Access maybe-absent fields with `integration["schema_name"]`
> or `integration.to_h`, which return `nil` rather than raising. On the current
> `better_auth` backend, the synced identity table is **`neon_auth.user`** (see
> [Manage users](#manage-users)); `users_sync` is the legacy Stack Auth name.

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

Neon Auth also syncs users into `neon_auth.user` in your database, so for reads
you can query that table directly from Rails. Note Better Auth's columns are
camelCase (`emailVerified`, `createdAt`, ...):

```sql
SELECT id, email, name FROM neon_auth.user;
```

### Verify JWTs at runtime

Your Rails app receives a Neon Auth JWT (typically in `Authorization: Bearer
<token>`) and verifies it against the project's JWKS endpoint:

```ruby
verifier = NeonAPI::Auth::JWTVerifier.new(jwks_url: ENV.fetch("NEON_AUTH_JWKS_URL"))
# or derive it from the integration:
verifier = auth.jwt_verifier(jwks_url: integration.jwks_url)

claims = verifier.verify(token)
claims.sub    #=> Neon Auth user id (matches neon_auth.user.id)
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

## Rails sign-in (server-side)

Managed Neon Auth (the `better_auth` backend) is **not** an OIDC provider — it
exposes no `/authorize`, OIDC `/token`, `/userinfo`, or discovery document, so an
`omniauth_openid_connect` relying-party flow can't complete against it. The path
that works for a server-rendered Rails app is Better Auth's server-side REST API,
wrapped by `NeonAPI::Auth::BetterAuthClient`: sign the user in, exchange the
session for a JWT, then verify it.

```ruby
class SessionsController < ApplicationController
  def create
    ba = NEON_AUTH.better_auth   # base_url pulled from the integration
    ba.sign_in_email(email: params[:email], password: params[:password])

    claims = NEON_AUTH_VERIFIER.verify(ba.token)   # the EdDSA JWT
    user = User.find_or_create_by!(neon_auth_id: claims.sub) do |u|
      u.email = claims.email
    end
    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in"
  rescue NeonAPI::AuthenticationError
    redirect_to login_path, alert: "Invalid email or password"
  end
end
```

`BetterAuthClient` handles the required `Origin` header and keeps a cookie jar, so
sign-in → `token` works on one instance; persist `ba.session_cookie` to resume a
session across requests. It wraps `sign_up_email`, `sign_in_email`, `get_session`,
`token`, and `sign_out`.

### Social sign-in ("Continue with Google")

For server-side social login, `NeonAPI::Auth::SocialAuth` (via `auth.social`)
initiates the provider flow and redeems the callback. Managed Neon Auth hands the
result back as a one-time `neon_auth_session_verifier`, and redeeming it also needs
the **challenge** that Neon sets at initiation — so you stash the challenge (e.g. in
the Rails session) and pass it back on the callback. No Node sidecar, no cookie
secret:

```ruby
class NeonSocialController < ApplicationController
  # GET /auth/neon/start
  def start
    init = neon_social.sign_in(provider: "google",
                              callback_url: neon_callback_url)
    session[:neon_challenge] = init.challenge
    redirect_to init.url, allow_other_host: true
  end

  # GET /auth/neon/callback?neon_auth_session_verifier=...
  def callback
    result = neon_social.redeem_callback(
      verifier:  params[:neon_auth_session_verifier],
      challenge: session.delete(:neon_challenge)
    )
    claims = NEON_AUTH_VERIFIER.verify(result.jwt)
    user = User.find_or_create_by!(neon_auth_id: claims.sub) { |u| u.email = claims.email }
    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in with Google"
  rescue NeonAPI::Auth::SocialAuthError
    redirect_to login_path, alert: "Sign-in could not be completed"
  end

  private

  def neon_social = NEON_AUTH.social
end
```

> The `callback_url` host must be **allow-listed** in the Neon Console (Auth →
> Configuration → Domains), or the browser redirect after consent won't reach your
> app. Configure the Google provider with `auth.oauth_providers.add(id: "google",
> client_id:, client_secret:)` for production (the shared dev keys show Neon's
> consent screen).

### Mountable Rack handler (mount and go)

Don't want to write the two routes yourself? `NeonAPI::Auth::RackHandler` is a
Rack app that serves the `start` and `callback` routes for you; you provide a
block that maps the verified identity to a local user:

```ruby
# config/initializers/neon_auth.rb
NEON_SOCIAL_HANDLER = NeonAPI::Auth::RackHandler.new(
  social:       NEON_AUTH.social,
  verifier:     NEON_AUTH_VERIFIER,
  callback_url: "https://app.example.com/auth/neon/callback"
) do |success|
  user = User.find_or_create_by!(neon_auth_id: success.claims.sub) { |u| u.email = success.claims.email }
  success.request.session[:user_id] = user.id
  "/"   # redirect target on success
end

# config/routes.rb
mount NEON_SOCIAL_HANDLER => "/auth/neon"   # → /auth/neon/start and /auth/neon/callback
```

It stashes the challenge in the Rack session between the two requests (so a
session middleware is required — Rails has one) and loads `rack` lazily.

### Rails convenience layer (optional)

If you're on Rails and want flash, route helpers, and a request-derived
`callback_url` (things a mounted Rack app gives up), configure Neon Auth once and
include a controller concern. The gem loads this layer only when Rails is present
— the core stays framework-agnostic.

```ruby
# config/initializers/neon_auth.rb
NeonAPI::Auth.configure do |c|
  c.base_url = ENV["NEON_AUTH_BASE_URL"]            # jwks_url derived unless set
  c.enabled  = c.base_url.present? && !Rails.env.test?
  c.find_user { |claims| User.find_or_create_from_neon_claims(claims) }  # the one app seam
end
```

This gives you derived accessors — `NeonAPI::Auth.enabled?`, `.verifier`,
`.social`, `.better_auth` — so apps stop hand-rolling that glue.

> **Thread-safety:** `.verifier` is memoized and safe to share (verification is
> read-only). `.social` and `.better_auth` return a **fresh** client each call —
> they carry a mutable cookie jar that must not be shared across threads — so use
> one per request/call (building does no network). The `Controller` concern
> already does this for you.

```ruby
class NeonSessionsController < ApplicationController
  include NeonAPI::Auth::Controller

  neon_auth callback_url: ->(_req) { neon_callback_url },          # request-derived; no APP_BASE_URL
            on_success:  ->(claims) {
              sign_in(neon_find_user(claims))
              redirect_to root_path, notice: "Signed in with Google."   # flash works
            },
            on_failure:  ->(error) { redirect_to login_path, alert: "Sign-in failed." }
end

# config/routes.rb
get "/auth/neon/start",    to: "neon_sessions#neon_social_start"
get "/auth/neon/callback", to: "neon_sessions#neon_social_callback"
```

The concern runs the challenge-stash / redeem / verify plumbing; your controller
keeps routes, helpers, flash, and session policy. The Neon clients are reached
through overridable methods (`neon_social`, `neon_verifier`), so request specs
stub those seams instead of `any_instance`. A generator scaffolds the initializer
and a `neon_auth_id` migration:

```sh
bin/rails g neon_auth:install
```

The full walkthrough — routes, controllers, JWT-protected API requests, and the
(self-hosted-only) OIDC helper — is in
[docs/rails_omniauth.md](docs/rails_omniauth.md).

> `NeonAPI::OmniAuth.openid_connect_options` remains for a **self-hosted** Better
> Auth deployment that runs the (non-managed) oidc-provider plugin, or another
> real OIDC provider fronting Neon. It does not work against managed Neon Auth.

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

## Reliability & instrumentation

The client retries transient failures automatically, with exponential backoff and
full jitter:

- **429 (rate limited)** — retried for any method (the request was never
  processed), honoring the `Retry-After` header when present.
- **5xx / network errors** — retried only for **idempotent** methods (GET/PUT/
  DELETE), since repeating a POST could double-write.

```ruby
client = NeonAPI.from_environ(
  max_retries: 2,            # 0 disables; default 2 → up to 3 tries
  retry_max_delay: 10.0      # cap on any single backoff (seconds)
)
```

Every request is wrapped in an instrumentation event (`"request.neon_api"`) you
can subscribe to — pass anything with an `ActiveSupport::Notifications`-style
`#instrument`:

```ruby
client = NeonAPI.from_environ(instrumenter: ActiveSupport::Notifications)

ActiveSupport::Notifications.subscribe("request.neon_api") do |*, payload|
  Rails.logger.info("neon #{payload[:method].upcase} #{payload[:path]} " \
                    "→ #{payload[:status]} (#{payload[:attempts]} attempt(s))")
end
```

`NeonAPI::RateLimitError#retry_after` exposes the parsed `Retry-After` seconds if
you handle throttling yourself.

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
