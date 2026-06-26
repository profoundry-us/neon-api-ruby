# Neon Auth in Rails (server-side sign-in + JWT)

This guide wires Neon Auth into a server-rendered Rails app:

1. **Server-side sign-in via Better Auth** — your Rails controller signs the user
   in against Neon Auth's REST API and exchanges the session for a JWT.
2. **API request verification via JWT** — your backend validates Neon Auth JWTs
   on each request (e.g. for a SPA or mobile client holding a token).

It assumes you've created a Neon project and have a `NEON_API_KEY`.

> **Why not `omniauth_openid_connect`?** Managed Neon Auth (the `better_auth`
> backend) is not an OIDC provider: it serves no OIDC discovery document,
> `/authorize`, `/token` (OIDC), or `/userinfo` endpoint, and there's no
> third-party OAuth client to register. A relying-party OIDC flow can't complete
> against it. The server-side REST flow below is the supported path. (If you run
> a **self-hosted** Better Auth with the oidc-provider plugin, see the appendix.)

---

## 1. One-time setup (provision the integration)

Run this once (a rake task or console session) to enable Neon Auth and configure
providers. Capture the integration details — you'll need `base_url` and
`jwks_url`.

```ruby
client = NeonAPI.from_environ
auth   = client.auth(ENV.fetch("NEON_PROJECT_ID"), ENV.fetch("NEON_BRANCH_ID"))

integration = auth.enable(auth_provider: "better_auth")

puts integration.to_h   # save base_url, jwks_url (+ keys, shown only once)
```

Store the details in Rails credentials (`bin/rails credentials:edit`):

```yaml
neon_auth:
  base_url: https://<endpoint>.neonauth.<region>.aws.neon.tech/<db>/auth
  jwks_url: https://<endpoint>.neonauth.<region>.aws.neon.tech/<db>/auth/.well-known/jwks.json
```

Memoize a Better Auth client and a JWT verifier in initializers:

```ruby
# config/initializers/neon_auth.rb
creds = Rails.application.credentials.neon_auth

NEON_AUTH = NeonAPI::Auth::BetterAuthClient.new(base_url: creds[:base_url])
NEON_AUTH_VERIFIER = NeonAPI::Auth::JWTVerifier.new(jwks_url: creds[:jwks_url])
```

> A single shared `BetterAuthClient` keeps an in-memory cookie jar, which is fine
> for a one-shot sign-in → token within a request. If you keep a user signed in
> against Neon Auth across requests, build a per-request client instead and
> persist `ba.session_cookie` (see [Sessions](#sessions-across-requests)).

---

## 2. Server-side sign-in

Routes:

```ruby
# config/routes.rb
get    "/login",  to: "sessions#new"
post   "/login",  to: "sessions#create"
post   "/signup", to: "sessions#signup"
delete "/logout", to: "sessions#destroy"
```

Sessions controller — sign in, fetch the JWT, verify it, and map to a local
`User`:

```ruby
class SessionsController < ApplicationController
  def create
    ba = NeonAPI::Auth::BetterAuthClient.new(base_url: neon_base_url)
    ba.sign_in_email(email: params[:email], password: params[:password])

    claims = NEON_AUTH_VERIFIER.verify(ba.token)
    user = User.find_or_create_by!(neon_auth_id: claims.sub) do |u|
      u.email = claims.email
    end
    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in"
  rescue NeonAPI::AuthenticationError
    redirect_to login_path, alert: "Invalid email or password"
  end

  def signup
    ba = NeonAPI::Auth::BetterAuthClient.new(base_url: neon_base_url)
    ba.sign_up_email(name: params[:name], email: params[:email], password: params[:password])
    ba.sign_in_email(email: params[:email], password: params[:password])

    claims = NEON_AUTH_VERIFIER.verify(ba.token)
    user = User.create!(neon_auth_id: claims.sub, email: claims.email, name: params[:name])
    session[:user_id] = user.id
    redirect_to root_path, notice: "Welcome!"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out"
  end

  private

  def neon_base_url
    Rails.application.credentials.neon_auth[:base_url]
  end
end
```

`claims.sub` is the Neon Auth user id and matches `neon_auth.user.id` in your
database, so server-side data joins line up. (`neon_auth.user` is Better Auth's
native table; columns are camelCase, e.g. `emailVerified`.)

### Sessions across requests

`sign_in_email` captures the Better Auth session cookie. To keep talking to Neon
Auth on later requests (e.g. `get_session` or refreshing the JWT), persist the
cookie and restore it:

```ruby
session[:neon_cookie] = ba.session_cookie     # after sign-in

# later request:
ba = NeonAPI::Auth::BetterAuthClient.new(base_url: neon_base_url)
ba.cookies = session[:neon_cookie]
fresh_jwt = ba.token
```

Most apps don't need this: verify the JWT once at sign-in, then rely on your own
Rails session (`session[:user_id]`).

---

## 3. API request verification with JWT

For a SPA/mobile client that already holds a Neon Auth JWT, verify it on each
request instead of using sessions.

A concern for controllers:

```ruby
# app/controllers/concerns/neon_authenticated.rb
module NeonAuthenticated
  extend ActiveSupport::Concern

  included { before_action :authenticate_neon_user! }

  private

  def authenticate_neon_user!
    token = request.authorization.to_s.sub(/\ABearer /, "")
    @neon_claims = NEON_AUTH_VERIFIER.verify(token)
    @current_user = User.find_by(neon_auth_id: @neon_claims.sub)
    head :unauthorized unless @current_user
  rescue NeonAPI::Auth::InvalidTokenError
    head :unauthorized
  end

  attr_reader :current_user, :neon_claims
end
```

Use it:

```ruby
class Api::NotesController < ApplicationController
  include NeonAuthenticated

  def index
    render json: current_user.notes
  end
end
```

Because `TokenExpiredError < InvalidTokenError`, the single `rescue` above
handles expired, forged, and malformed tokens alike. To signal expiry
specifically (so the client knows to refresh):

```ruby
rescue NeonAPI::Auth::TokenExpiredError
  response.set_header("WWW-Authenticate", 'Bearer error="invalid_token"')
  head :unauthorized
rescue NeonAPI::Auth::InvalidTokenError
  head :unauthorized
end
```

---

## 4. Optional Rails layer (kill the boilerplate)

Sections 1–3 hand-roll config resolution, a memoized verifier, and the
redeem/verify wiring. The gem ships an optional Rails layer (loaded only when
Rails is present) so you supply only what's genuinely yours — the claims→user
mapping and your session/redirect policy.

Configure once:

```ruby
# config/initializers/neon_auth.rb
NeonAPI::Auth.configure do |c|
  c.base_url = ENV["NEON_AUTH_BASE_URL"]            # jwks_url derived unless set
  c.enabled  = c.base_url.present? && !Rails.env.test?
  c.find_user { |claims| User.find_or_create_from_neon_claims(claims) }
end
```

You get memoized accessors — `NeonAPI::Auth.enabled?`, `.verifier`, `.social`,
`.better_auth` — replacing the `app/services/neon_auth.rb` boilerplate.

For social sign-in, include the controller concern so the flow lives in *your*
controller with flash, route helpers, and a request-derived `callback_url`:

```ruby
class NeonSessionsController < ApplicationController
  include NeonAPI::Auth::Controller

  neon_auth callback_url: ->(_req) { neon_callback_url },
            on_success:  ->(claims) {
              sign_in(neon_find_user(claims))
              redirect_to root_path, notice: "Signed in with Google."
            },
            on_failure:  ->(error) { redirect_to login_path, alert: "Sign-in failed." }
end

# config/routes.rb
get "/auth/neon/start",    to: "neon_sessions#neon_social_start"
get "/auth/neon/callback", to: "neon_sessions#neon_social_callback"
```

`neon_social` / `neon_verifier` are overridable instance methods, so request
specs stub those seams instead of `allow_any_instance_of`. Scaffold the
initializer and a `neon_auth_id` migration with `bin/rails g neon_auth:install`.

This is the Rails-native alternative to the framework-agnostic
`NeonAPI::Auth::RackHandler` (see the [README](../README.md#mountable-rack-handler-mount-and-go)),
which you'd reach for in non-Rails Rack apps.

---

## Notes

- **EdDSA:** Neon Auth uses Ed25519 by default — add `gem "rbnacl"` so the `jwt`
  gem can verify those signatures. See
  [neon_auth.md](neon_auth.md#eddsa-dependency).
- **Key rotation:** the verifier refreshes the JWKS automatically when it sees a
  new key id, so rotations don't require a deploy.
- **Reads from the DB:** Neon Auth syncs users into `neon_auth.user`. You can
  read profile data straight from Postgres instead of calling the API.

---

## Appendix: OIDC via OmniAuth (self-hosted Better Auth only)

`NeonAPI::OmniAuth.openid_connect_options` builds the options hash for the
[`omniauth_openid_connect`](https://github.com/omniauth/omniauth_openid_connect)
strategy. **This does not work against managed Neon Auth** (no OIDC endpoints, no
third-party client registration). It is useful only if you front Neon with a real
OIDC provider — e.g. a self-hosted Better Auth running the oidc-provider plugin.

```ruby
# config/initializers/omniauth.rb (self-hosted OIDC only)
creds = Rails.application.credentials.neon_auth

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect, NeonAPI::OmniAuth.openid_connect_options(
    integration: { "base_url" => creds[:base_url], "jwks_url" => creds[:jwks_url] },
    client_id: creds[:client_id],
    client_secret: creds[:client_secret],
    redirect_uri: "#{ENV.fetch('APP_URL')}/auth/openid_connect/callback"
  )
end
```

The helper derives the authorize/token/userinfo/JWKS endpoints from `base_url`;
override any of them via `client_options:` (deep-merged) or pass `issuer:`.
