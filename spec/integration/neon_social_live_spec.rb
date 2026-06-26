# frozen_string_literal: true

# Opt-in LIVE social (OAuth) sign-in test. Skipped (and never touches the
# network) unless NEON_API_KEY is set.
#
# The initiate half (`social.sign_in`) runs automatically. The redeem half needs
# a real provider consent, which can't be automated (consent/CAPTCHA), so it runs
# only when you supply a manually-captured verifier + challenge:
#
#   1. Run, with NEON_API_KEY set, just the initiate example — or call
#      `auth.social.sign_in(provider: "google", callback_url: "http://localhost:3000/cb")`
#      in a console — and open the returned `url` in a browser.
#   2. Complete the Google consent. Neon redirects to your callback with
#      `?neon_auth_session_verifier=<verifier>` (allow-list the callback host in
#      the Neon Console first, or it bounces to Neon's root — the verifier is
#      still in the URL either way).
#   3. Re-run with the captured values:
#        NEON_API_KEY=... \
#        NEON_SOCIAL_VERIFIER=<verifier> \
#        NEON_SOCIAL_CHALLENGE='__Secure-neon-auth.session_challange=<value>' \
#        bundle exec rspec spec/integration/neon_social_live_spec.rb
#
# The verifier + challenge are single-use and expire ~10 minutes after initiate.

RSpec.describe "Neon Auth social sign-in (live)", :integration do
  before(:all) do
    WebMock.allow_net_connect! if ENV["NEON_API_KEY"]
  end

  after(:all) { WebMock.disable_net_connect! }

  before do
    skip "set NEON_API_KEY to run the live social sign-in test" unless ENV["NEON_API_KEY"]
  end

  let(:client) { NeonAPI.from_environ }

  let(:project_id) { ENV["NEON_PROJECT_ID"] || Array(client.projects.to_h["projects"]).first&.fetch("id") }

  let(:branch_id) do
    ENV["NEON_BRANCH_ID"] || begin
      branches = Array(client.branches(project_id).to_h["branches"])
      (branches.find { |b| b["default"] } || branches.first)&.fetch("id")
    end
  end

  let(:auth) { client.auth(project_id, branch_id) }
  let(:social) { auth.social }

  it "initiates a social sign-in (server-side, no consent)" do
    init = social.sign_in(provider: "google", callback_url: "http://localhost:3000/auth/neon/callback")

    expect(init.url).to include("/sign-in/social/init?token=")
    expect(init.challenge).to include("session_challange=")
  end

  it "redeems a manually-captured callback into a verified identity" do
    verifier  = ENV.fetch("NEON_SOCIAL_VERIFIER", nil)
    challenge = ENV.fetch("NEON_SOCIAL_CHALLENGE", nil)
    unless verifier && challenge
      skip "set NEON_SOCIAL_VERIFIER and NEON_SOCIAL_CHALLENGE (captured from a browser consent) to run"
    end

    result = social.redeem_callback(verifier: verifier, challenge: challenge)

    expect(result.jwt).to be_a(String)
    claims = auth.jwt_verifier.verify(result.jwt)
    expect(claims.sub).to eq(result.session.to_h.dig("user", "id"))
  end
end
