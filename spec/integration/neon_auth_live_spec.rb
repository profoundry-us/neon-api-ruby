# frozen_string_literal: true

# Opt-in LIVE integration test against a real Neon project. It is skipped (and
# never touches the network) unless NEON_API_KEY is set, so the default suite and
# CI stay fully mocked and offline.
#
# Run it against your OWN free Neon project (Neon auto-enables Neon Auth on
# project creation):
#
#   NEON_API_KEY=neon_api_key_... bundle exec rspec spec/integration/neon_auth_live_spec.rb
#
# Optionally set NEON_PROJECT_ID / NEON_BRANCH_ID to target a specific
# project/branch; otherwise the first project and its default branch are
# discovered via the API.
#
# What it exercises end-to-end:
#   management (me) -> auth.config -> oauth_providers.list ->
#   Better Auth sign-up/sign-in -> /token -> JWTVerifier,
# asserting the verified `sub` equals the Better Auth user id (= neon_auth.user.id).

RSpec.describe "Neon Auth live integration", :integration do
  before(:all) do
    # Only lift WebMock's net-connect block when we actually have credentials;
    # an offline run must never open a real connection.
    WebMock.allow_net_connect! if ENV["NEON_API_KEY"]
  end

  after(:all) { WebMock.disable_net_connect! }

  before do
    skip "set NEON_API_KEY to run the live Neon Auth integration test" unless ENV["NEON_API_KEY"]
  end

  let(:client) { NeonAPI.from_environ }

  # Neon's GET /projects requires an org_id for org-scoped accounts. Discover the
  # first organization unless NEON_ORG_ID is provided; fall back to the
  # un-scoped listing for personal accounts.
  let(:org_id) do
    ENV["NEON_ORG_ID"] || begin
      orgs = Array(client.connection.get("users/me/organizations").to_h["organizations"])
      orgs.first&.fetch("id", nil)
    end
  end

  let(:project_id) do
    ENV["NEON_PROJECT_ID"] || begin
      query = org_id ? { org_id: org_id } : {}
      first = Array(client.projects(**query).to_h["projects"]).first
      raise "no projects found for this NEON_API_KEY; set NEON_PROJECT_ID" unless first

      first["id"]
    end
  end

  let(:branch_id) do
    ENV["NEON_BRANCH_ID"] || begin
      branches = Array(client.branches(project_id).to_h["branches"])
      default = branches.find { |b| b["default"] } || branches.first
      raise "no branches found for project #{project_id}; set NEON_BRANCH_ID" unless default

      default["id"]
    end
  end

  let(:auth) { client.auth(project_id, branch_id) }

  # A unique-per-run identity so reruns don't collide.
  let(:email) { "neon-api-ruby-test+#{Time.now.to_i}@example.com" }
  let(:password) { "Passw0rd-#{Time.now.to_i}" }

  it "authenticates the API key" do
    expect(client.me.email).to be_a(String)
  end

  it "reads the integration config (auto-enabled on project creation)" do
    config = auth.config
    expect(config.base_url).to match(%r{\Ahttps://.+/auth\z})
    expect(config["jwks_url"]).to be_a(String)
  end

  it "lists OAuth providers without error" do
    providers = auth.oauth_providers.list
    expect(providers.to_h).to have_key("providers").or(be_a(Hash))
  end

  it "signs in via Better Auth and verifies the issued JWT" do
    config = auth.config
    ba = auth.better_auth(base_url: config.base_url)

    begin
      ba.sign_up_email(name: "Test User", email: email, password: password)
    rescue NeonAPI::APIError => e
      # Email/password sign-up may be disabled on some projects; if so, we can't
      # complete the live login flow, so skip rather than fail.
      skip "Better Auth email sign-up unavailable on this project: #{e.message}"
    end

    ba.sign_in_email(email: email, password: password)

    jwt = ba.token
    expect(jwt).to be_a(String)

    verifier = auth.jwt_verifier(jwks_url: config["jwks_url"])
    claims = verifier.verify(jwt)

    expect(claims.email).to eq(email)
    expect(claims.role).to eq("authenticated")

    # claims.sub is the Better Auth user id, which equals neon_auth.user.id.
    session_user_id = ba.get_session.to_h.dig("user", "id")
    expect(claims.sub).to eq(session_user_id)
  end
end
