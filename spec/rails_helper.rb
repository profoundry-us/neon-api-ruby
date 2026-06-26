# frozen_string_literal: true

# Boots a minimal in-process Rails app (via Combustion) so the Rails layer can
# be exercised against a real request cycle. Used only by spec/rails, under the
# isolated gemfiles/rails.gemfile bundle.
require "spec_helper"
require "combustion"

# Ensure our Railtie is registered before the app initializes (spec_helper
# required neon_api before Rails existed, so the conditional require was a no-op).
require "neon_api/rails/railtie"

Combustion.initialize!(:action_controller) do
  config.secret_key_base = "neon-api-ruby-combustion-secret-key-base-0123456789"
  config.session_store :cookie_store, key: "_neon_internal_session"
  config.action_dispatch.show_exceptions = false
end

require "rack/test"

RSpec.configure do |config|
  config.include Rack::Test::Methods

  # Each example starts from a clean global Neon Auth configuration.
  config.before { NeonAPI::Auth.reset! }
  config.after  { NeonAPI::Auth.reset! }
end

# The Rack app under test for Rack::Test::Methods.
def app
  Rails.application
end
