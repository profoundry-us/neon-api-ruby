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
| `table_name` | DB table users sync into (`users_sync`) |
| `base_url` | hosted auth base URL |

`create` is an alias for `enable`.

### `config` / `get`

```ruby
auth.config.jwks_url
auth.config.base_url
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

For reads, you can also query the synced table directly:

```sql
SELECT id, email, name FROM neon_auth.users_sync WHERE deleted_at IS NULL;
```

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
claims.sub        # user id (also: claims.user_id) — matches users_sync.id
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
