# frozen_string_literal: true

# Neon Auth configuration. See https://github.com/profoundry-us/neon-api-ruby
NeonAPI::Auth.configure do |c|
  # Hosted auth base URL from your integration (".../<db>/auth").
  # jwks_url is derived from this unless you set c.jwks_url explicitly.
  c.base_url = ENV["NEON_AUTH_BASE_URL"]

  # Active when base_url is present; disabled in test for hermetic specs.
  c.enabled = c.base_url.present? && !Rails.env.test?

  # The one app-specific seam: map verified Claims to your user.
  c.find_user do |claims|
    User.find_or_initialize_by(neon_auth_id: claims.sub).tap do |user|
      user.email = claims.email
      user.save!
    end
  end
end
