# Neon Auth in Rails (OmniAuth + JWT)

This guide wires Neon Auth into a Rails app two complementary ways:

1. **Browser sign-in via OmniAuth** — users log in with Google/GitHub/etc.
   through Neon Auth's OAuth providers.
2. **API request verification via JWT** — your backend validates Neon Auth JWTs
   on each request (e.g. for a SPA or mobile client).

It assumes you've created a Neon project and have a `NEON_API_KEY`.

---

## 1. One-time setup (provision the integration)

Run this once (a rake task or console session) to enable Neon Auth and configure
providers. Capture the integration details — you'll need `base_url`, `jwks_url`,
and the client keys.

```ruby
client = NeonAPI.from_environ
auth   = client.auth(ENV.fetch("NEON_PROJECT_ID"), ENV.fetch("NEON_BRANCH_ID"))

integration = auth.enable(auth_provider: "better_auth")

auth.oauth_providers.add(
  id: "google",
  client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
  client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET")
)

puts integration.to_h   # save base_url, jwks_url, pub_client_key, secret_server_key
```

Store the secrets in Rails credentials (`bin/rails credentials:edit`):

```yaml
neon_auth:
  base_url: https://...
  jwks_url: https://.../.well-known/jwks.json
  client_id: ...
  client_secret: ...
```

---

## 2. Browser sign-in with OmniAuth

Add the strategy gem:

```ruby
# Gemfile
gem "neon-api"
gem "omniauth_openid_connect"
gem "omniauth-rails_csrf_protection" # CSRF protection for the request phase
```

Configure the middleware from the integration:

```ruby
# config/initializers/omniauth.rb
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

> The helper derives the authorize/token/userinfo/JWKS endpoints from
> `base_url`. If your Neon Auth project uses a non-standard layout, override any
> of them by passing `client_options:` (it's deep-merged), or pass `issuer:`.

Routes:

```ruby
# config/routes.rb
get  "/auth/:provider/callback", to: "sessions#create"
post "/auth/:provider/callback", to: "sessions#create"
get  "/auth/failure",            to: "sessions#failure"
delete "/logout",                to: "sessions#destroy"
```

A sign-in link (POST, for CSRF protection):

```erb
<%= button_to "Sign in with Neon Auth", "/auth/openid_connect", method: :post %>
```

Sessions controller — map the OmniAuth identity to a local `User`:

```ruby
class SessionsController < ApplicationController
  def create
    info = request.env["omniauth.auth"]
    user = User.find_or_create_by!(neon_auth_id: info.uid) do |u|
      u.email = info.info.email
      u.name  = info.info.name
    end
    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out"
  end

  def failure
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end
end
```

`neon_auth_id` (the OmniAuth `uid`) is the Neon Auth user id and matches
`neon_auth.users_sync.id` in your database, so server-side data joins line up.

---

## 3. API request verification with JWT

For a SPA/mobile client that already holds a Neon Auth JWT, verify it on each
request instead of using sessions.

Memoize a verifier in an initializer:

```ruby
# config/initializers/neon_auth.rb
NEON_AUTH_VERIFIER = NeonAPI::Auth::JWTVerifier.new(
  jwks_url: Rails.application.credentials.neon_auth[:jwks_url]
)
```

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
handles expired, forged, and malformed tokens alike. If you want to signal
expiry specifically (so the client knows to refresh):

```ruby
rescue NeonAPI::Auth::TokenExpiredError
  response.set_header("WWW-Authenticate", 'Bearer error="invalid_token"')
  head :unauthorized
rescue NeonAPI::Auth::InvalidTokenError
  head :unauthorized
end
```

---

## Notes

- **EdDSA:** Neon Auth uses Ed25519 by default — add `gem "rbnacl"` so the `jwt`
  gem can verify those signatures. See
  [neon_auth.md](neon_auth.md#eddsa-dependency).
- **Key rotation:** the verifier refreshes the JWKS automatically when it sees a
  new key id, so rotations don't require a deploy.
- **Reads from the DB:** Neon Auth syncs users into `neon_auth.users_sync`. You
  can read profile data straight from Postgres instead of calling the API.
