# frozen_string_literal: true

RSpec.describe NeonAPI::Auth::BetterAuthClient do
  subject(:client) { described_class.new(base_url: base_url) }

  let(:base_url) { "https://ep-cool-darkness-123.neonauth.us-east-2.aws.neon.tech/neondb/auth" }
  let(:origin)   { "https://ep-cool-darkness-123.neonauth.us-east-2.aws.neon.tech" }
  let(:session_cookie) { "better-auth.session_token=sess-abc123" }

  def stub_ba(method, path, status: 200, body: {}, set_cookie: nil)
    response = {
      status: status,
      body: body.is_a?(String) ? body : JSON.generate(body),
      headers: { "Content-Type" => "application/json" }
    }
    response[:headers]["Set-Cookie"] = set_cookie if set_cookie
    stub_request(method, "#{base_url}/#{path}").to_return(response)
  end

  describe "#initialize" do
    it "requires a base_url" do
      expect { described_class.new(base_url: nil) }.to raise_error(ArgumentError)
      expect { described_class.new(base_url: "") }.to raise_error(ArgumentError)
    end

    it "derives the Origin from the base_url's scheme and host" do
      expect(client.origin).to eq(origin)
    end

    it "honors an explicit origin override" do
      custom = described_class.new(base_url: base_url, origin: "https://app.example.com")
      expect(custom.origin).to eq("https://app.example.com")
    end

    it "preserves a non-default port in the derived origin" do
      local = described_class.new(base_url: "http://localhost:3000/neondb/auth")
      expect(local.origin).to eq("http://localhost:3000")
    end

    it "strips a trailing slash from base_url" do
      expect(described_class.new(base_url: "#{base_url}/").base_url).to eq(base_url)
    end
  end

  describe "#sign_in_email" do
    it "POSTs credentials with the required Origin header and JSON content type" do
      stub = stub_ba(:post, "sign-in/email", body: { user: { id: "u1" } })
      client.sign_in_email(email: "ada@example.com", password: "Passw0rd-123456")

      expect(
        a_request(:post, "#{base_url}/sign-in/email").with(
          headers: { "Origin" => origin, "Content-Type" => "application/json" },
          body: { email: "ada@example.com", password: "Passw0rd-123456" }
        )
      ).to have_been_made
      expect(stub).to have_been_requested
    end

    it "captures the session cookie set by the response" do
      stub_ba(:post, "sign-in/email", set_cookie: "#{session_cookie}; Path=/; HttpOnly")
      client.sign_in_email(email: "ada@example.com", password: "pw")

      expect(client.cookies).to include("better-auth.session_token" => "sess-abc123")
      expect(client.session_cookie).to eq(session_cookie)
    end

    it "returns the parsed response as a NeonAPI::Object" do
      stub_ba(:post, "sign-in/email", body: { user: { id: "u1", email: "ada@example.com" } })
      result = client.sign_in_email(email: "ada@example.com", password: "pw")

      expect(result).to be_a(NeonAPI::Object)
      expect(result.user.email).to eq("ada@example.com")
    end
  end

  describe "#sign_up_email" do
    it "POSTs name, email, and password" do
      stub_ba(:post, "sign-up/email", body: { user: { id: "u2" } })
      client.sign_up_email(name: "Ada", email: "ada@example.com", password: "pw")

      expect(
        a_request(:post, "#{base_url}/sign-up/email").with(
          body: { name: "Ada", email: "ada@example.com", password: "pw" }
        )
      ).to have_been_made
    end

    it "omits name when not given" do
      stub_ba(:post, "sign-up/email")
      client.sign_up_email(email: "ada@example.com", password: "pw")

      expect(
        a_request(:post, "#{base_url}/sign-up/email")
          .with(body: { email: "ada@example.com", password: "pw" })
      ).to have_been_made
    end
  end

  describe "#token" do
    it "sends the captured session cookie and returns the JWT string" do
      stub_ba(:post, "sign-in/email", set_cookie: "#{session_cookie}; Path=/")
      stub_ba(:get, "token", body: { token: "eyJhbG.signed.jwt" })

      client.sign_in_email(email: "ada@example.com", password: "pw")
      jwt = client.token

      expect(jwt).to eq("eyJhbG.signed.jwt")
      expect(
        a_request(:get, "#{base_url}/token").with(headers: { "Cookie" => session_cookie })
      ).to have_been_made
    end

    it "returns nil when no token is present" do
      stub_ba(:get, "token", body: {})
      expect(client.token).to be_nil
    end
  end

  describe "#session / #get_session" do
    it "GETs the current session" do
      stub_ba(:get, "get-session", body: { user: { id: "u1" }, session: { id: "s1" } })
      session = client.get_session

      expect(session.user.id).to eq("u1")
      expect(a_request(:get, "#{base_url}/get-session")).to have_been_made
    end
  end

  describe "#sign_out" do
    it "POSTs sign-out and clears the cookie jar" do
      stub_ba(:post, "sign-in/email", set_cookie: "#{session_cookie}; Path=/")
      stub_ba(:post, "sign-out", body: { success: true })

      client.sign_in_email(email: "ada@example.com", password: "pw")
      expect(client.session_cookie).not_to be_nil

      client.sign_out
      expect(client.cookies).to be_empty
      expect(client.session_cookie).to be_nil
    end
  end

  describe "#healthy?" do
    it "returns true on a 200 from /ok" do
      stub_ba(:get, "ok", body: "OK")
      expect(client.healthy?).to be(true)
    end

    it "returns false when /ok errors" do
      stub_ba(:get, "ok", status: 503, body: "down")
      expect(client.healthy?).to be(false)
    end
  end

  describe "session resumption" do
    it "accepts a raw Cookie string and sends it on the next request" do
      client.cookies = session_cookie
      stub_ba(:get, "token", body: { token: "jwt" })

      client.token
      expect(
        a_request(:get, "#{base_url}/token").with(headers: { "Cookie" => session_cookie })
      ).to have_been_made
    end

    it "accepts a hash of cookies" do
      client.cookies = { "better-auth.session_token" => "sess-abc123" }
      expect(client.session_cookie).to eq(session_cookie)
    end
  end

  describe "error handling" do
    it "raises a mapped APIError on a 400" do
      stub_ba(:post, "sign-in/email", status: 400, body: { message: "Invalid body", code: "BAD_REQUEST" })
      expect { client.sign_in_email(email: "x", password: "y") }
        .to raise_error(NeonAPI::BadRequestError, /Invalid body/)
    end

    it "raises AuthenticationError on a 401 with the Better Auth message" do
      stub_ba(:post, "sign-in/email", status: 401, body: { message: "Invalid email or password" })
      expect { client.sign_in_email(email: "x", password: "y") }
        .to raise_error(NeonAPI::AuthenticationError, /Invalid email or password/)
    end

    it "wraps network failures in NeonAPI::Error" do
      stub_request(:get, "#{base_url}/token").to_raise(Errno::ECONNREFUSED)
      expect { client.token }.to raise_error(NeonAPI::Error, /Network error talking to Neon Auth/)
    end
  end
end
