# frozen_string_literal: true

Rails.application.routes.draw do
  get "/auth/neon/start",    to: "neon_sessions#neon_social_start"
  get "/auth/neon/callback", to: "neon_sessions#neon_social_callback", as: :neon_callback

  # Inert landing routes the controller redirects to.
  get "/welcome", to: ->(_env) { [200, { "content-type" => "text/plain" }, ["welcome"]] }
  get "/login",   to: ->(_env) { [200, { "content-type" => "text/plain" }, ["login"]] }
end
