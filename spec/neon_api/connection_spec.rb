# frozen_string_literal: true

RSpec.describe NeonAPI::Connection do
  # Default to no real sleeping; retry-specific examples build their own.
  subject(:connection) { described_class.new(api_key: "neon_api_key_test", sleeper: ->(_s) {}) }

  describe "#initialize" do
    it "requires an api key" do
      expect { described_class.new(api_key: nil) }.to raise_error(NeonAPI::ConfigurationError)
      expect { described_class.new(api_key: "") }.to raise_error(NeonAPI::ConfigurationError)
    end

    it "defaults to the Neon production base URL with a trailing slash" do
      expect(connection.base_url.to_s).to eq("https://console.neon.tech/api/v2/")
    end

    it "normalizes a base URL without a trailing slash" do
      conn = described_class.new(api_key: "k", base_url: "https://example.test/api/v2")
      expect(conn.base_url.to_s).to eq("https://example.test/api/v2/")
    end
  end

  describe "request building" do
    it "sends the api key as a Bearer token and JSON headers" do
      stub = stub_request(:get, "https://console.neon.tech/api/v2/users/me")
             .with(headers: {
                     "Authorization" => "Bearer neon_api_key_test",
                     "Content-Type" => "application/json",
                     "Accept" => "application/json"
                   })
             .to_return(status: 200, body: "{}")

      connection.get("users/me")
      expect(stub).to have_been_requested
    end

    it "sets a descriptive User-Agent" do
      stub = stub_request(:get, "https://console.neon.tech/api/v2/x")
             .with { |req| req.headers["User-Agent"].include?("neon-api-ruby/#{NeonAPI::VERSION}") }
             .to_return(status: 200, body: "{}")
      connection.get("x")
      expect(stub).to have_been_requested
    end

    it "preserves the /api/v2 prefix even for absolute-looking paths" do
      stub = stub_request(:get, "https://console.neon.tech/api/v2/projects/p1")
             .to_return(status: 200, body: "{}")
      connection.get("/projects/p1")
      expect(stub).to have_been_requested
    end

    it "encodes query parameters and drops nil values" do
      stub = stub_request(:get, "https://console.neon.tech/api/v2/projects")
             .with(query: { "limit" => "10" })
             .to_return(status: 200, body: "{}")
      connection.get("projects", query: { limit: 10, cursor: nil })
      expect(stub).to have_been_requested
    end

    it "JSON-encodes request bodies" do
      stub = stub_request(:post, "https://console.neon.tech/api/v2/api_keys")
             .with(body: { key_name: "ci" })
             .to_return(status: 200, body: "{}")
      connection.post("api_keys", body: { key_name: "ci" })
      expect(stub).to have_been_requested
    end
  end

  describe "response parsing" do
    it "parses JSON bodies" do
      stub_request(:get, "https://console.neon.tech/api/v2/x").to_return(status: 200, body: '{"a":1}')
      expect(connection.get("x")).to eq("a" => 1)
    end

    it "returns nil for empty success bodies" do
      stub_request(:delete, "https://console.neon.tech/api/v2/x").to_return(status: 200, body: "")
      expect(connection.delete("x")).to be_nil
    end
  end

  describe "error handling" do
    {
      400 => NeonAPI::BadRequestError,
      401 => NeonAPI::AuthenticationError,
      403 => NeonAPI::ForbiddenError,
      404 => NeonAPI::NotFoundError,
      409 => NeonAPI::ConflictError,
      422 => NeonAPI::UnprocessableEntityError,
      429 => NeonAPI::RateLimitError,
      500 => NeonAPI::ServerError,
      503 => NeonAPI::ServerError
    }.each do |status, klass|
      it "raises #{klass} on HTTP #{status}" do
        stub_request(:get, "https://console.neon.tech/api/v2/x")
          .to_return(status: status, body: '{"message":"boom"}')
        expect { connection.get("x") }.to raise_error(klass)
      end
    end

    it "includes status, parsed body, request, and request id on the error" do
      stub_request(:get, "https://console.neon.tech/api/v2/projects/missing")
        .to_return(
          status: 404,
          body: '{"message":"project not found"}',
          headers: { "x-neon-request-id" => "req_123" }
        )

      expect { connection.get("projects/missing") }.to raise_error(NeonAPI::NotFoundError) do |error|
        expect(error.status).to eq(404)
        expect(error.body).to eq("message" => "project not found")
        expect(error.request).to eq("GET /projects/missing")
        expect(error.request_id).to eq("req_123")
        expect(error.message).to include("HTTP 404", "project not found", "req_123")
      end
    end

    it "wraps network failures in NeonAPI::Error" do
      stub_request(:get, "https://console.neon.tech/api/v2/x").to_raise(SocketError.new("no dns"))
      expect { connection.get("x") }.to raise_error(NeonAPI::Error, /Network error/)
    end
  end

  describe "retries" do
    let(:url) { "https://console.neon.tech/api/v2/x" }

    def conn(**opts)
      described_class.new(api_key: "k", sleeper: ->(_s) {}, **opts)
    end

    it "retries a 429, then succeeds" do
      stub_request(:get, url).to_return({ status: 429, body: "{}" }, { status: 200, body: '{"ok":true}' })
      expect(conn.get("x")).to eq("ok" => true)
      expect(a_request(:get, url)).to have_been_made.twice
    end

    it "honors Retry-After on a 429 for the backoff" do
      delays = []
      stub_request(:get, url).to_return({ status: 429, headers: { "Retry-After" => "2" }, body: "{}" },
                                        { status: 200, body: "{}" })
      conn(sleeper: ->(s) { delays << s }).get("x")
      expect(delays).to eq([2.0])
    end

    it "retries transient 5xx for idempotent methods" do
      stub_request(:get, url).to_return({ status: 503, body: "{}" }, { status: 200, body: '{"ok":1}' })
      expect(conn.get("x")).to eq("ok" => 1)
      expect(a_request(:get, url)).to have_been_made.twice
    end

    it "does not retry 5xx for non-idempotent methods" do
      stub_request(:post, url).to_return(status: 500, body: "{}")
      expect { conn.post("x") }.to raise_error(NeonAPI::ServerError)
      expect(a_request(:post, url)).to have_been_made.once
    end

    it "does not retry 4xx caller errors" do
      stub_request(:get, url).to_return(status: 400, body: "{}")
      expect { conn.get("x") }.to raise_error(NeonAPI::BadRequestError)
      expect(a_request(:get, url)).to have_been_made.once
    end

    it "gives up after max_retries and raises" do
      stub_request(:get, url).to_return(status: 500, body: "{}")
      expect { conn(max_retries: 2).get("x") }.to raise_error(NeonAPI::ServerError)
      expect(a_request(:get, url)).to have_been_made.times(3) # 1 + 2 retries
    end

    it "retries network errors for idempotent methods" do
      stub_request(:get, url).to_raise(Errno::ECONNREFUSED).then.to_return(status: 200, body: "{}")
      expect(conn.get("x")).to eq({})
      expect(a_request(:get, url)).to have_been_made.twice
    end

    it "can be disabled with max_retries: 0" do
      stub_request(:get, url).to_return(status: 503, body: "{}")
      expect { conn(max_retries: 0).get("x") }.to raise_error(NeonAPI::ServerError)
      expect(a_request(:get, url)).to have_been_made.once
    end
  end

  describe "instrumentation" do
    let(:url) { "https://console.neon.tech/api/v2/x" }

    it "instruments each request with method, path, status, and attempts" do
      events = []
      recorder = Object.new
      recorder.define_singleton_method(:instrument) do |name, payload, &blk|
        blk.call.tap { events << [name, payload.dup] }
      end

      stub_request(:get, url).to_return({ status: 429, body: "{}" }, { status: 200, body: "{}" })
      described_class.new(api_key: "k", instrumenter: recorder, sleeper: ->(_s) {}).get("x")

      name, payload = events.last
      expect(name).to eq("request.neon_api")
      expect(payload).to include(method: :get, path: "x", status: 200, attempts: 2)
    end
  end
end
