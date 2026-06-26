# Neon Auth reference

This document covers the `NeonAPI::Auth` surface in depth. For a high-level tour
see the [README](../README.md); for the Rails wiring see
[rails_omniauth.md](rails_omniauth.md).

## Concepts

- **Integration** — a Neon Auth setup attached to a **project + branch**. Most
  apps enable it on the project's default branch.
- **Provider backend** (`auth_provider`) — the engine behind the integration.
  Neon Auth currently uses `better_auth` (default); `stack` is also accepted.
- **OAuth providers** — the social sign-in options the integration offers
  (Google, GitHub, Microsoft, Vercel). Distinct from the provider backend.
- **JWKS** — the public key set used to verify the JWTs Neon Auth issues.

Get a branch-scoped handle:

```ruby
client = NeonAPI.from_environ
auth   = client.auth(project_id, branch_id)
```

`auth` is a `NeonAPI::Auth::Branch`.

## Lifecycle

### `enable(auth_provider: "better_auth", database_name: nil)`

Provisions the integration. The response is the **only** time the secret server
key is shown — store it securely (e.g. Rails credentials).

```ruby
integration = auth.enable(auth_provider: "better_auth", database_name: "neondb")
```

| Field | Meaning |
| ----- | ------- |
| `auth_provider` | the backend in use |
| `auth_provider_project_id` | the backend's project id |
| `pub_client_key` | publishable client key — safe for browsers |
| `secret_server_key` | **secret** server key — keep private |
| `jwks_url` | JWKS endpoint for verifying tokens |
| `schema_name` | DB schema users sync into (`neon_auth`) |
| `table_name` | reported as `users_sync`, but see the note below |
| `base_url` | hosted auth base URL |

> ⚠️ On the `better_auth` backend, `enable` still reports
> `table_name: "users_sync"`, but **that table does not exist**. The live
> `neon_auth` schema is Better Auth's native one — `user`, `account`, `session`,
> `organization`, … — so read identity from `neon_auth.user` (see
> [Users](#users)). `users_sync` is the legacy Stack Auth name. Verified against
> a live project: `claims.sub == neon_auth.user.id`.

`create` is an alias for `enable`.

### `config` / `get`

```ruby
auth.config.jwks_url
auth.config.base_url
```

`config` returns a **subset** of what `enable` returns:
`auth_provider`, `auth_provider_project_id`, `base_url`, `branch_id`,
`created_at`, `db_name`, `jwks_url`, `name`, `owned_by`. It does **not** include
`pub_client_key` / `secret_server_key` (shown only once, by `enable`) nor
`schema_name` / `table_name`. Method-style access to an absent key raises
`NoMethodError`, so reach for maybe-absent fields with the hash form, which
returns `nil`:

```ruby
auth.config["schema_name"]   #=> nil (not present on config)
auth.config.to_h             # the full hash, for safe inspection
```

### `update(**attributes)`

```ruby
auth.update(name: "My Application")
```

### `disable(delete_data: false)`

```ruby
auth.disable                    # remove integration, keep synced user data
auth.disable(delete_data: true) # also drop the synced data
```

`destroy` is an alias for `disable`.

## OAuth providers

`auth.oauth_providers` returns a `NeonAPI::Auth::OAuthProviders`.

```ruby
providers = auth.oauth_providers

providers.list                  # => configured providers
providers.add(id: "google", client_id: "...", client_secret: "...")
providers.update("google", client_secret: "rotated")
providers.delete("google")
```

- `id` must be one of `OAuthProviders::SUPPORTED`
  (`google`, `github`, `microsoft`, `vercel`); anything else raises
  `ArgumentError` before a request is made.
- Omit `client_id` / `client_secret` to use Neon's **shared development keys**.
  Always supply your own credentials in production.
- Microsoft may require `microsoft_tenant_id:`.

Aliases: `add` ↔ `create`, `delete` ↔ `remove`, `list` ↔ `all`.

## Users

`auth.users` returns a `NeonAPI::Auth::Users`.

```ruby
users = auth.users

users.create(email: "ada@example.com", password: "s3cret", display_name: "Ada")
users.update(user_id, display_name: "Ada L.")
users.set_role(user_id, role: "admin")  # convenience around update
users.delete(user_id)
```

For reads, you can also query the synced table directly. On `better_auth` the
table is `neon_auth.user`, with Better Auth's native (camelCase) columns —
`id`, `name`, `email`, `emailVerified`, `image`, `createdAt`, `updatedAt`,
`role`, `banned`, `banReason`, `banExpires`:

```sql
SELECT id, email, name FROM neon_auth.user;
```

## Server-side sign-in (Better Auth)

`auth.better_auth` returns a `NeonAPI::Auth::BetterAuthClient` — a wrapper around
Better Auth's server-side REST API. This is the supported path for signing users
in from a server-rendered Rails app, because managed Neon Auth is **not** an OIDC
provider (no `/authorize`, OIDC `/token`, `/userinfo`, or discovery document — so
`omniauth_openid_connect` can't be used against it).

```ruby
ba = auth.better_auth                       # base_url fetched from config
# or: auth.better_auth(base_url: integration.base_url)   # no extra API call

ba.sign_up_email(name: "Ada", email: "ada@example.com", password: "Passw0rd-123456")
ba.sign_in_email(email: "ada@example.com", password: "Passw0rd-123456")
ba.token        # => the EdDSA JWT (verify it with JWTVerifier)
ba.get_session  # => current session
ba.sign_out
```

- Better Auth's endpoints enforce a CSRF guard requiring an `Origin` header
  matching the auth host. The client sends it automatically (derived from
  `base_url`); override with `better_auth(origin: "https://app.example.com")`.
- Sign-in sets a session cookie; the client keeps a cookie jar, so
  `sign_in_email` → `token` works on one instance. Persist `ba.session_cookie`
  (and restore it with `ba.cookies = saved`) to resume a session across requests.
- Errors map to the same `NeonAPI::APIError` subclasses as the management API
  (e.g. a bad password raises `NeonAPI::AuthenticationError`).

See [rails_omniauth.md](rails_omniauth.md) for a full Rails controller example.

## Social sign-in (OAuth)

`auth.social` returns a `NeonAPI::Auth::SocialAuth` for server-side social login
("Continue with Google") — no Node sidecar, no client-side JS.

Managed Neon Auth hands a completed social sign-in back as a **one-time
`neon_auth_session_verifier`**. Redeeming it also requires the **challenge** that
Neon sets at initiation, so the flow is two steps with the challenge stashed in
between (e.g. the Rails session):

```ruby
social = auth.social                # base_url fetched from config

# 1. Initiate — redirect the browser to init.url, stash init.challenge
init = social.sign_in(provider: "google",
                      callback_url: "https://app.example.com/auth/neon/callback")
init.url        # => send the browser here
init.challenge  # => stash (e.g. session[:neon_challenge])

# 2. Redeem — on the callback, with the verifier from the query + the challenge
result = social.redeem_callback(verifier: verifier_from_query, challenge: stashed_challenge)
result.jwt            # => EdDSA JWT (verify with JWTVerifier)
result.session.user   # => the Neon user (user.id == neon_auth.user.id)
result.session_token  # => session cookie, to resume the Neon session if needed
```

- **Initiation is server-side**: `sign_in` calls `POST /sign-in/social` and
  captures the challenge cookie; the browser only follows `init.url`.
- **Redemption needs no secret**: `redeem_callback` presents the verifier +
  challenge to `get-session` (Neon decrypts server-side) and exchanges the
  resulting session for the JWT. You do **not** need `NEON_AUTH_COOKIE_SECRET` or
  any project secret.
- **Allow-list the callback host** in the Neon Console (Auth → Configuration →
  Domains), or the post-consent browser redirect won't reach your app. Redemption
  itself doesn't depend on it.
- A bad/expired/already-used verifier raises `NeonAPI::Auth::SocialAuthError`.
- Configure the provider with your own keys via `auth.oauth_providers.add(id:
  "google", client_id:, client_secret:)` for production; omit them to use Neon's
  shared dev keys (which show Neon's consent screen).

## JWT verification

`NeonAPI::Auth::JWTVerifier` validates Neon Auth JWTs against the project's JWKS.

```ruby
verifier = NeonAPI::Auth::JWTVerifier.new(
  jwks_url: integration.jwks_url,
  algorithms: %w[EdDSA RS256], # default
  issuer: nil,                 # if set, the `iss` claim must match
  audience: nil,               # if set, the `aud` claim must match
  leeway: 0,                   # clock-skew tolerance, seconds
  cache_ttl: 600               # JWKS cache lifetime, seconds
)
```

Or build one from a branch handle (fetches `jwks_url` from `config` if you don't
pass it):

```ruby
verifier = auth.jwt_verifier(jwks_url: integration.jwks_url)
```

### Verifying

```ruby
claims = verifier.verify(token)            # raises on failure
claims = verifier.verify?(token)           # => Claims or nil
claims = verifier.verify(token, audience: "my-app") # per-call override
```

`verify` raises:

- `NeonAPI::Auth::TokenExpiredError` — well-formed, correctly signed, but expired
- `NeonAPI::Auth::InvalidTokenError` — anything else (bad signature, malformed,
  empty, issuer/audience mismatch, JWKS unreachable)

Both inherit from `NeonAPI::Error`, and `TokenExpiredError < InvalidTokenError`,
so a single `rescue NeonAPI::Auth::InvalidTokenError` catches all token failures.

### Claims

```ruby
claims.sub        # user id (also: claims.user_id) — matches neon_auth.user.id
claims.email
claims.role       # typically "authenticated"
claims.expires_at # Time
claims.issued_at  # Time
claims["custom"]  # any other claim
claims.to_h       # the full verified payload
```

### Caching & key rotation

- The JWKS is fetched once and cached for `cache_ttl` seconds.
- If a token references an unknown key id (`kid`) — e.g. right after Neon rotates
  keys — the verifier refreshes the JWKS **once** and retries before failing.
- Call `verifier.reset_cache!` to force a refresh on the next verification.

A `JWTVerifier` is safe to memoize and reuse across requests (it guards JWKS
fetches with a mutex).

### EdDSA dependency

Neon Auth signs with EdDSA (Ed25519) by default. The `jwt` gem needs `rbnacl`
for EdDSA:

```ruby
gem "rbnacl", "~> 7.1"
```

If the `jwt` gem itself is missing, the verifier raises
`NeonAPI::ConfigurationError` with guidance. RS256 projects need nothing extra.
