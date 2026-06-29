# frozen_string_literal: true

# Helpers shared across specs: a known base URL and convenience builders for
# stubbing Neon API responses with WebMock.
module APIHelpers
  BASE_URL = "https://console.neon.tech/api/v2"
  API_KEY = "neon_api_key_test"

  # A no-op sleeper so retry-triggering specs (429/5xx) don't actually sleep.
  NO_SLEEP = ->(_seconds) {}

  def client(api_key: API_KEY, **options)
    NeonAPI::Client.new(api_key: api_key, sleeper: NO_SLEEP, **options)
  end

  # Stub a JSON endpoint. Returns the WebMock stub so callers can assert on it.
  #
  # @example
  #   stub = stub_neon(:get, "users/me", body: { email: "a@b.c" })
  def stub_neon(method, path, status: 200, body: {}, request_body: nil, query: nil)
    url = "#{BASE_URL}/#{path}"
    stub = stub_request(method, url)
    stub = stub.with(query: query) if query
    stub = stub.with(body: request_body) if request_body
    stub.to_return(
      status: status,
      body: body.is_a?(String) ? body : JSON.generate(body),
      headers: { "Content-Type" => "application/json" }
    )
  end
end

RSpec.configure do |config|
  config.include APIHelpers
end
