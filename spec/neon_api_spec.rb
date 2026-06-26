# frozen_string_literal: true

RSpec.describe NeonAPI do
  it "has a version number" do
    expect(NeonAPI::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  describe "top-level factories" do
    it ".new builds a client from an api key" do
      expect(described_class.new(api_key: "k")).to be_a(NeonAPI::Client)
    end

    it ".from_token builds a client" do
      expect(described_class.from_token("tok")).to be_a(NeonAPI::Client)
    end

    it ".from_environ / .from_env read NEON_API_KEY" do
      stub_const("ENV", ENV.to_hash.merge("NEON_API_KEY" => "k"))
      expect(described_class.from_environ).to be_a(NeonAPI::Client)
      expect(described_class.from_env).to be_a(NeonAPI::Client)
    end
  end
end
