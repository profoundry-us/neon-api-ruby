# frozen_string_literal: true

require "rails_helper"

# Drives NeonAPI::Auth::Controller through a real Rails request cycle (Combustion)
# to confirm the things the unit spec's fake controller can't: real route
# helpers, redirect_to(allow_other_host:), the session round-trip between the two
# requests, and app callbacks running in controller context with flash.
RSpec.describe "Neon social sign-in (Rails/Combustion)", type: :request do
  let(:social)   { instance_double(NeonAPI::Auth::SocialAuth) }
  let(:verifier) { instance_double(NeonAPI::Auth::JWTVerifier) }

  before do
    NeonAPI::Auth.configure do |c|
      c.base_url = "https://ep-x.neonauth.us-east-1.aws.neon.tech/neondb/auth"
      c.find_user { |claims| "user-for-#{claims.sub}" }
    end
    # Inject doubles at the seam the controller reads from.
    allow(NeonAPI::Auth).to receive_messages(social: social, verifier: verifier)
  end

  def start_flow(challenge: "ch-1")
    allow(social).to receive(:sign_in).and_return(
      NeonAPI::Auth::SocialAuth::Initiation.new(url: "https://neon/init?token=t", challenge: challenge)
    )
    get "/auth/neon/start", provider: "google"
  end

  describe "GET /auth/neon/start" do
    it "redirects to the provider with allow_other_host and stashes the challenge" do
      start_flow

      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq("https://neon/init?token=t")
    end

    it "passes the request-derived callback_url (a real route helper) to sign_in" do
      start_flow

      expect(social).to have_received(:sign_in).with(
        hash_including(provider: "google", callback_url: a_string_matching(%r{://[^/]+/auth/neon/callback\z}))
      )
    end
  end

  describe "GET /auth/neon/callback" do
    let(:result) { NeonAPI::Auth::SocialAuth::Result.new(jwt: "the.jwt", session_token: "st", session: nil) }
    let(:claims) { NeonAPI::Auth::Claims.new("sub" => "u-9", "email" => "ada@example.com") }

    it "redeems with the round-tripped challenge, verifies, and runs on_success" do
      start_flow # sets the challenge in the session cookie carried to the next request
      allow(social).to receive(:redeem_callback).and_return(result)
      allow(verifier).to receive(:verify).with("the.jwt").and_return(claims)

      get "/auth/neon/callback", neon_auth_session_verifier: "V"

      expect(social).to have_received(:redeem_callback).with(verifier: "V", challenge: "ch-1")
      expect(last_response.status).to eq(302)
      expect(last_response.location).to match(%r{/welcome\z})
      expect(last_request.env["rack.session"][:user_id]).to eq("user-for-u-9")
      expect(last_request.env["action_dispatch.request.flash_hash"].to_h).to include("notice" => /Signed in as ada@example.com/)
    end

    it "runs on_failure (with flash) when redemption fails" do
      start_flow
      allow(social).to receive(:redeem_callback).and_raise(NeonAPI::Auth::SocialAuthError.new("expired"))

      get "/auth/neon/callback", neon_auth_session_verifier: "bad"

      expect(last_response.status).to eq(302)
      expect(last_response.location).to match(%r{/login\z})
    end
  end

  describe "the Railtie" do
    it "registers an initializer that disables Neon Auth in the test environment" do
      expect(Rails.env.test?).to be(true)
      initializer = Rails.application.initializers.find { |i| i.name == "neon_api.auth.defaults" }
      expect(initializer).not_to be_nil

      NeonAPI::Auth.reset! # enabled => nil (auto)
      initializer.run(Rails.application)
      expect(NeonAPI::Auth.config.enabled).to be(false)
    end
  end
end
