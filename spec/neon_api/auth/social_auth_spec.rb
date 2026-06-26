# frozen_string_literal: true

RSpec.describe NeonAPI::Auth::SocialAuth do
  subject(:social) { described_class.new(base_url: base_url) }

  let(:base_url)  { "https://ep-cool-darkness-123.neonauth.us-east-2.aws.neon.tech/neondb/auth" }
  let(:origin)    { "https://ep-cool-darkness-123.neonauth.us-east-2.aws.neon.tech" }
  let(:challenge) { "__Secure-neon-auth.session_challange=chal-abc123" }
  let(:session_token) { "__Secure-neon-auth.session_token=tok-xyz789" }

  def stub_social(method, path, status: 200, body: {}, set_cookie: nil, query: nil)
    response = {
      status: status,
      body: body.is_a?(String) ? body : JSON.generate(body),
      headers: { "Content-Type" => "application/json" }
    }
    response[:headers]["Set-Cookie"] = set_cookie if set_cookie
    stub = stub_request(method, "#{base_url}/#{path}")
    stub = stub.with(query: query) if query
    stub.to_return(response)
  end

  describe "#sign_in" do
    it "POSTs to /sign-in/social with the Origin header and provider body" do
      stub_social(:post, "sign-in/social", body: { url: "#{base_url}/sign-in/social/init?token=t1" })
      social.sign_in(provider: "google", callback_url: "https://app.example.com/auth/neon/callback")

      expect(
        a_request(:post, "#{base_url}/sign-in/social").with(
          headers: { "Origin" => origin },
          body: {
            provider: "google",
            callbackURL: "https://app.example.com/auth/neon/callback",
            errorCallbackURL: "https://app.example.com/auth/neon/callback"
          }
        )
      ).to have_been_made
    end

    it "honors a distinct error_callback_url" do
      stub_social(:post, "sign-in/social", body: { url: "#{base_url}/x" })
      social.sign_in(provider: "google", callback_url: "https://app/cb", error_callback_url: "https://app/err")

      expect(
        a_request(:post, "#{base_url}/sign-in/social")
          .with(body: hash_including(callbackURL: "https://app/cb", errorCallbackURL: "https://app/err"))
      ).to have_been_made
    end

    it "returns the redirect URL and the captured challenge" do
      init_url = "#{base_url}/sign-in/social/init?token=t1"
      stub_social(:post, "sign-in/social", body: { url: init_url },
                                           set_cookie: "#{challenge}; Max-Age=600; HttpOnly; Secure; SameSite=None")

      init = social.sign_in(provider: "google", callback_url: "https://app/cb")

      expect(init.url).to eq(init_url)
      expect(init.challenge).to eq(challenge)
    end

    it "raises SocialAuthError if no URL is returned" do
      stub_social(:post, "sign-in/social", body: { redirect: true })
      expect { social.sign_in(provider: "google", callback_url: "https://app/cb") }
        .to raise_error(NeonAPI::Auth::SocialAuthError, /did not return a social sign-in URL/)
    end

    it "validates required arguments" do
      expect { social.sign_in(provider: "", callback_url: "https://app/cb") }.to raise_error(ArgumentError)
      expect { social.sign_in(provider: "google", callback_url: nil) }.to raise_error(ArgumentError)
    end
  end

  describe "#redeem_callback" do
    let(:verifier) { "vfy-123" }

    def stub_get_session(body:, set_cookie: nil)
      stub_social(:get, "get-session", query: { "neon_auth_session_verifier" => verifier },
                                       body: body, set_cookie: set_cookie)
    end

    it "redeems the verifier+challenge into a session and JWT" do
      stub_get_session(body: { session: { id: "s1" }, user: { id: "user-uuid-1", email: "ada@x.com" } },
                       set_cookie: "#{session_token}; Path=/; HttpOnly; Secure")
      stub_social(:get, "token", body: { token: "eyJ.signed.jwt" })

      result = social.redeem_callback(verifier: verifier, challenge: challenge)

      expect(result.jwt).to eq("eyJ.signed.jwt")
      expect(result.session_token).to eq(session_token)
      expect(result.session.user.id).to eq("user-uuid-1")
    end

    it "sends the verifier query and the challenge cookie to get-session" do
      stub_get_session(body: { user: { id: "u1" } }, set_cookie: "#{session_token}; Path=/")
      stub_social(:get, "token", body: { token: "jwt" })

      social.redeem_callback(verifier: verifier, challenge: challenge)

      expect(
        a_request(:get, "#{base_url}/get-session")
          .with(query: { "neon_auth_session_verifier" => verifier },
                headers: { "Cookie" => challenge })
      ).to have_been_made
    end

    it "sends the captured session_token cookie to /token" do
      stub_get_session(body: { user: { id: "u1" } }, set_cookie: "#{session_token}; Path=/")
      stub_social(:get, "token", body: { token: "jwt" })

      social.redeem_callback(verifier: verifier, challenge: challenge)

      expect(
        a_request(:get, "#{base_url}/token").with(headers: { "Cookie" => /session_token=tok-xyz789/ })
      ).to have_been_made
    end

    it "raises SocialAuthError when the verifier can't be redeemed (null session)" do
      stub_get_session(body: "null")
      token_stub = stub_social(:get, "token", body: { token: "should-not-be-called" })

      expect { social.redeem_callback(verifier: verifier, challenge: challenge) }
        .to raise_error(NeonAPI::Auth::SocialAuthError, /expired, already used, or invalid/)
      expect(token_stub).not_to have_been_requested
    end

    it "raises SocialAuthError when redeemed but no JWT is issued" do
      stub_get_session(body: { user: { id: "u1" } }, set_cookie: "#{session_token}; Path=/")
      stub_social(:get, "token", body: {})

      expect { social.redeem_callback(verifier: verifier, challenge: challenge) }
        .to raise_error(NeonAPI::Auth::SocialAuthError, /no JWT was issued/)
    end

    it "validates required arguments" do
      expect { social.redeem_callback(verifier: "", challenge: challenge) }.to raise_error(ArgumentError)
      expect { social.redeem_callback(verifier: verifier, challenge: nil) }.to raise_error(ArgumentError)
    end
  end

  describe "error handling" do
    it "maps a non-2xx initiate to a NeonAPI::APIError" do
      stub_social(:post, "sign-in/social", status: 400, body: { message: "bad provider" })
      expect { social.sign_in(provider: "nope", callback_url: "https://app/cb") }
        .to raise_error(NeonAPI::BadRequestError, /bad provider/)
    end
  end
end
