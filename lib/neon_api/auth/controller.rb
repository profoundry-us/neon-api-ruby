# frozen_string_literal: true

module NeonAPI
  module Auth
    # An includable controller concern for server-side social sign-in on Rails,
    # keeping flash, route helpers, and a request-derived `callback_url` in your
    # own controller — unlike the boot-time {RackHandler}, which trades those
    # away. It runs the social initiate/redeem/verify plumbing; your app supplies
    # the claims→user mapping (via {Configuration#find_user}) and its session /
    # redirect policy (via the `on_success` / `on_failure` callbacks).
    #
    # Plain Ruby (no ActiveSupport dependency) — include it into any controller
    # that exposes `params`, `session`, `request`, and `redirect_to`.
    #
    # @example
    #   class NeonSessionsController < ApplicationController
    #     include NeonAPI::Auth::Controller
    #
    #     neon_auth callback_url: ->(_req) { neon_callback_url },   # request-derived
    #               on_success:  ->(claims) {
    #                 sign_in(neon_find_user(claims))
    #                 redirect_to root_path, notice: "Signed in with Google."
    #               },
    #               on_failure:  ->(error) { redirect_to login_path, alert: "Sign-in failed." }
    #   end
    #
    #   # config/routes.rb
    #   get "/auth/neon/start",    to: "neon_sessions#neon_social_start"
    #   get "/auth/neon/callback", to: "neon_sessions#neon_social_callback"
    #
    # ## Testability
    #
    # The Neon clients are reached through overridable instance methods
    # ({#neon_social}, {#neon_verifier}), so request specs can stub those seams
    # instead of `allow_any_instance_of`.
    module Controller
      # Per-controller settings captured by the {ClassMethods#neon_auth} DSL.
      Settings = Struct.new(:callback_url, :error_callback_url, :on_success, :on_failure,
                            :provider_param, :verifier_param, :challenge_key, keyword_init: true)

      def self.included(base)
        base.extend(ClassMethods)
      end

      # Class-level DSL added to the including controller.
      module ClassMethods
        # Configure the Neon Auth flow for this controller.
        #
        # @param callback_url [String, #call] the callback URL, or a callable
        #   invoked in controller context with the request (e.g. a route helper)
        # @param on_success [#call] run in controller context with the verified
        #   {Claims}; establish the session / redirect here
        # @param on_failure [#call] run in controller context with the error;
        #   redirect / flash here
        # @param error_callback_url [String, #call, nil] where Neon redirects on
        #   provider error (defaults to `callback_url`)
        # @param provider_param [Symbol] request param holding the provider id
        # @param verifier_param [Symbol] callback param holding the verifier
        # @param challenge_key [Symbol] session key the challenge is stashed under
        def neon_auth(callback_url:, on_success:, on_failure:, error_callback_url: nil,
                      provider_param: :provider, verifier_param: :neon_auth_session_verifier,
                      challenge_key: :neon_auth_challenge)
          @neon_auth_settings = Settings.new(
            callback_url: callback_url, error_callback_url: error_callback_url,
            on_success: on_success, on_failure: on_failure,
            provider_param: provider_param, verifier_param: verifier_param,
            challenge_key: challenge_key
          )
        end

        # @return [Settings, nil] this controller's settings (inherited if unset)
        def neon_auth_settings
          return @neon_auth_settings if defined?(@neon_auth_settings) && @neon_auth_settings
          return superclass.neon_auth_settings if superclass.respond_to?(:neon_auth_settings)

          nil
        end
      end

      # GET action: initiate social sign-in and redirect the browser to the
      # provider. Stashes the challenge in the session for the callback.
      def neon_social_start
        settings = neon_auth_settings!
        init = neon_social.sign_in(
          provider: params[settings.provider_param],
          callback_url: neon_resolved_url(settings.callback_url),
          error_callback_url: neon_resolved_url(settings.error_callback_url)
        )
        session[settings.challenge_key] = init.challenge
        redirect_to init.url, allow_other_host: true
      end

      # GET action: redeem the callback handoff, verify the JWT, and hand the
      # verified claims to `on_success` (or the error to `on_failure`).
      def neon_social_callback
        settings = neon_auth_settings!
        challenge = session.delete(settings.challenge_key)

        if (error = params[:error]) && !neon_blank?(error)
          return neon_run(settings.on_failure, SocialAuthError.new("provider returned error: #{error}"))
        end

        result = neon_social.redeem_callback(verifier: params[settings.verifier_param], challenge: challenge)
        claims = neon_verifier.verify(result.jwt)
        neon_run(settings.on_success, claims)
      rescue NeonAPI::Auth::SocialAuthError, NeonAPI::Auth::InvalidTokenError, ArgumentError => e
        neon_run(settings.on_failure, e)
      end

      # --- Overridable seams (stub these in specs instead of any_instance) ---

      # A per-request {SocialAuth}. `NeonAPI::Auth.social` returns a fresh client
      # each call (its cookie jar must not be shared across threads); memoizing on
      # the controller — which Rails instantiates per request — keeps one client
      # for the duration of the request without leaking it to other threads.
      # @return [SocialAuth]
      def neon_social
        @neon_social ||= NeonAPI::Auth.social
      end

      # @return [JWTVerifier] the shared, memoized (read-only) verifier
      def neon_verifier
        NeonAPI::Auth.verifier
      end

      # Map verified claims to your app's user via the configured identity hook.
      def neon_find_user(claims)
        NeonAPI::Auth.find_user(claims)
      end

      private

      def neon_auth_settings
        self.class.neon_auth_settings
      end

      def neon_auth_settings!
        neon_auth_settings ||
          raise(NeonAPI::ConfigurationError, "call `neon_auth ...` in #{self.class} to configure Neon Auth")
      end

      def neon_resolved_url(value)
        return nil if value.nil?

        value.respond_to?(:call) ? instance_exec(request, &value) : value
      end

      # Run an app callback in controller context, honoring its arity (a 0-arity
      # callback gets no argument; otherwise it receives the claims / error).
      def neon_run(callback, arg)
        return if callback.nil?

        if callback.respond_to?(:arity) && callback.arity.zero?
          instance_exec(&callback)
        else
          instance_exec(arg, &callback)
        end
      end

      def neon_blank?(value)
        value.nil? || value.to_s.empty?
      end
    end
  end
end
