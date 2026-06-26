# frozen_string_literal: true

require "neon_api"
require "webmock/rspec"

# Load local-only env vars (e.g. NEON_PROJECT_ID for the opt-in live integration
# spec). Never in CI, and a missing .env or missing gem is fine. Dotenv does not
# override variables already set in the shell.
unless ENV["CI"]
  begin
    require "dotenv"
    Dotenv.load
  rescue LoadError
    # dotenv isn't installed; nothing to load.
  end
end

# All HTTP is mocked; no test should ever touch the network.
WebMock.disable_net_connect!

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.example_status_persistence_file_path = ".rspec_status"
end
