# frozen_string_literal: true

require "rack"

RSpec.describe NeonAPI::Auth::RackHandler do
  let(:social)   { instance_double(NeonAPI::Auth::SocialAuth) }
  let(:verifier) { instance_double(NeonAPI::Auth::JWTVerifier) }
  let(:callback_url) { "https://app.example.com/auth/neon/callback" }
  let(:init) do
    NeonAPI::Auth::SocialAuth::Initiation.new(
      url: "https://neon/sign-in/social/init?token=t1",
      challenge: "__Secure-neon-auth.session_challange=chal-1"
    )
  end

  # Build a handler whose success block records what it saw and logs the user in.
  def build_handler(on_error: nil, &block)
    success_block = block || proc do |success|
      success.request.session[:user_id] = success.claims.sub
      "/dashboard"
    end
    described_class.new(social: social, verifier: verifier, callback_url: callback_url,
                        on_error: on_error, &success_block)
  end

  # Call the handler with a persistent session hash (stands in for the session
  # middleware that Rails provides).
  def call(handler, path, session, params: {})
    env = Rack::MockRequest.env_for(path, params: params)
    env["rack.session"] = session
    handler.call(env)
  end

  describe "start" do
    it "initiates the flow, stashes the challenge, and 302s to the provider URL" do
      allow(social).to receive(:sign_in)
        .with(provider: "google", callback_url: callback_url).and_return(init)
      session = {}

      status, headers, = call(build_handler, "/start", session)

      expect(status).to eq(302)
      expect(headers["location"]).to eq(init.url)
      expect(session["neon_challenge"]).to eq("__Secure-neon-auth.session_challange=chal-1")
    end

    it "passes a provider override from the query" do
      allow(social).to receive(:sign_in)
        .with(provider: "github", callback_url: callback_url).and_return(init)

      call(build_handler, "/start", {}, params: { "provider" => "github" })

      expect(social).to have_received(:sign_in).with(provider: "github", callback_url: callback_url)
    end
  end

  describe "callback" do
    let(:result) do
      NeonAPI::Auth::SocialAuth::Result.new(jwt: "jwt.token", session_token: "st=1",
                                            session: NeonAPI::Object.new("user" => { "id" => "user-1" }))
    end
    let(:claims) { instance_double(NeonAPI::Auth::Claims, sub: "user-1", email: "ada@x.com") }

    it "redeems with the stashed challenge, verifies the JWT, and runs the success block" do
      session = { "neon_challenge" => "__Secure-neon-auth.session_challange=chal-1" }
      allow(social).to receive(:redeem_callback)
        .with(verifier: "vfy-1", challenge: "__Secure-neon-auth.session_challange=chal-1")
        .and_return(result)
      allow(verifier).to receive(:verify).with("jwt.token").and_return(claims)

      status, headers, = call(build_handler, "/callback", session,
                              params: { "neon_auth_session_verifier" => "vfy-1" })

      expect(status).to eq(302)
      expect(headers["location"]).to eq("/dashboard")
      expect(session[:user_id]).to eq("user-1")          # success block logged the user in
      expect(session).not_to have_key("neon_challenge")  # challenge consumed
    end

    it "returns a 400 when redemption fails and no on_error is set" do
      session = { "neon_challenge" => "chal" }
      allow(social).to receive(:redeem_callback)
        .and_raise(NeonAPI::Auth::SocialAuthError, "expired verifier")

      status, _headers, body = call(build_handler, "/callback", session,
                                    params: { "neon_auth_session_verifier" => "vfy-1" })

      expect(status).to eq(400)
      expect(body.join).to include("expired verifier")
    end

    it "delegates failures to on_error when provided" do
      session = { "neon_challenge" => "chal" }
      allow(social).to receive(:redeem_callback)
        .and_raise(NeonAPI::Auth::SocialAuthError, "bad")
      on_error = ->(_error, _request) { "/login?error=1" }

      status, headers, = call(build_handler(on_error: on_error), "/callback", session,
                              params: { "neon_auth_session_verifier" => "vfy-1" })

      expect(status).to eq(302)
      expect(headers["location"]).to eq("/login?error=1")
    end

    it "lets the success block return a full Rack response triple" do
      session = { "neon_challenge" => "chal" }
      allow(social).to receive(:redeem_callback).and_return(result)
      allow(verifier).to receive(:verify).and_return(claims)
      handler = build_handler { |_s| [201, { "content-type" => "text/plain" }, ["ok"]] }

      status, _headers, body = call(handler, "/callback", session,
                                    params: { "neon_auth_session_verifier" => "vfy-1" })

      expect(status).to eq(201)
      expect(body.join).to eq("ok")
    end
  end

  describe "routing and config" do
    it "404s for unknown paths" do
      status, = call(build_handler, "/nope", {})
      expect(status).to eq(404)
    end

    it "requires a success block" do
      expect { described_class.new(social: social, verifier: verifier, callback_url: callback_url) }
        .to raise_error(ArgumentError, /success block/)
    end
  end
end
