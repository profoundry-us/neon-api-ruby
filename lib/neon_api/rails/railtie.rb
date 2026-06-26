# frozen_string_literal: true

require "rails/railtie"

module NeonAPI
  module Auth
    # Wires Rails-environment defaults for the optional convenience layer. Loaded
    # only when Rails is present (guarded in neon_api.rb), so the core gem stays
    # framework-agnostic.
    class Railtie < Rails::Railtie
      # Default Neon Auth to disabled in the test environment (so specs stay
      # hermetic) unless the app sets it explicitly. App initializers run after
      # this, so `NeonAPI::Auth.configure { |c| c.enabled = true }` still wins.
      initializer "neon_api.auth.defaults", before: :load_config_initializers do
        NeonAPI::Auth.config.enabled = false if Rails.env.test? && NeonAPI::Auth.config.enabled.nil?
      end
    end
  end
end
