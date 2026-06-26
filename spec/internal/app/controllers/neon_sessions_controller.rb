# frozen_string_literal: true

# Exercises NeonAPI::Auth::Controller inside a real Rails request cycle (flash,
# route helpers, redirect_to allow_other_host, session) under Combustion.
class NeonSessionsController < ApplicationController
  include NeonAPI::Auth::Controller

  neon_auth callback_url: ->(_req) { neon_callback_url }, # request-derived route helper
            on_success: lambda { |claims|
              session[:user_id] = neon_find_user(claims)
              redirect_to "/welcome", notice: "Signed in as #{claims.email}."
            },
            on_failure: lambda { |error|
              redirect_to "/login", alert: "Sign-in failed: #{error.message}"
            }
end
