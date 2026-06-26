# frozen_string_literal: true

require_relative "social_auth"

module NeonAPI
  module Auth
    # A Rack-mountable handler for server-side social sign-in — the "mount and go"
    # layer over {SocialAuth}. It mirrors the role of Neon's
    # `createNeonAuth().handler()`: a **start** route that initiates the provider
    # flow and a **callback** route that redeems the handoff, verifies the JWT,
    # and hands you the identity.
    #
    # It carries the one-time challenge between the two requests via the Rack
    # session (`env["rack.session"]`), so a session middleware is required (Rails
    # has one). `rack` is loaded lazily — it is not a runtime dependency of the
    # gem; your Rails/Rack app already provides it.
    #
    # You supply a success block that receives the verified {Claims} (and the Rack
    # request, so you can set your own session) and returns either a redirect URL
    # string or a full Rack response triple.
    #
    # @example Rails (config/routes.rb)
    #   handler = NeonAPI::Auth::RackHandler.new(
    #     social:       client.auth(pid, bid).social,
    #     verifier:     client.auth(pid, bid).jwt_verifier,
    #     callback_url: "https://app.example.com/auth/neon/callback"
    #   ) do |success|
    #     user = User.find_or_create_by!(neon_auth_id: success.claims.sub)
    #     success.request.session[:user_id] = user.id
    #     "/"   # redirect here on success
    #   end
    #
    #   mount handler => "/auth/neon"   # serves /auth/neon/start and /auth/neon/callback
    class RackHandler
      # Passed to the success block: the verified claims, the raw {SocialAuth::Result},
      # and the Rack::Request (use `request.session` to log the user in).
      Success = Struct.new(:claims, :result, :request, keyword_init: true)

      # @param social [SocialAuth] a configured social client (e.g. `auth.social`)
      # @param verifier [JWTVerifier] used to verify the redeemed JWT
      # @param callback_url [String] the full callback URL (must match the mounted
      #   callback route and be allow-listed in the Neon Console)
      # @param provider [String] default provider when none is given in params
      # @param start_path [String] path (relative to the mount) that initiates
      # @param callback_path [String] path (relative to the mount) that redeems
      # @param challenge_session_key [String] session key used to stash the challenge
      # @param verifier_param [String] callback query param holding the verifier
      # @param on_error [#call, nil] optional `->(error, request)` returning a
      #   redirect URL or Rack response; a plain 400 is returned otherwise
      # @yieldparam success [Success]
      # @yieldreturn [String, Array] a redirect URL or a Rack response triple
      def initialize(social:, verifier:, callback_url:, provider: "google",
                     start_path: "/start", callback_path: "/callback",
                     challenge_session_key: "neon_challenge",
                     verifier_param: "neon_auth_session_verifier",
                     on_error: nil, &on_success)
        require_rack!
        raise ArgumentError, "a success block is required" unless on_success

        @social = social
        @verifier = verifier
        @callback_url = callback_url
        @provider = provider
        @start_path = start_path
        @callback_path = callback_path
        @challenge_session_key = challenge_session_key
        @verifier_param = verifier_param
        @on_error = on_error
        @on_success = on_success
      end

      # @param env [Hash] the Rack environment
      # @return [Array] a Rack response triple
      def call(env)
        request = Rack::Request.new(env)
        case request.path_info
        when @start_path    then handle_start(request)
        when @callback_path then handle_callback(request)
        else text(404, "Not found")
        end
      end

      private

      def handle_start(request)
        provider = request.params["provider"] || @provider
        init = @social.sign_in(provider: provider, callback_url: @callback_url)
        session(request)[@challenge_session_key] = init.challenge
        redirect(init.url)
      rescue NeonAPI::Error, ArgumentError => e
        handle_error(e, request)
      end

      def handle_callback(request)
        verifier = request.params[@verifier_param]
        challenge = session(request).delete(@challenge_session_key)
        result = @social.redeem_callback(verifier: verifier, challenge: challenge)
        claims = @verifier.verify(result.jwt)
        finish(@on_success.call(Success.new(claims: claims, result: result, request: request)))
      rescue NeonAPI::Error, ArgumentError => e
        handle_error(e, request)
      end

      def handle_error(error, request)
        return finish(@on_error.call(error, request)) if @on_error

        text(400, "Neon Auth sign-in failed: #{error.message}")
      end

      def session(request)
        request.session ||
          raise(NeonAPI::ConfigurationError, "NeonAPI::Auth::RackHandler requires a Rack session middleware")
      end

      # A success/error handler may return a redirect URL string or a full Rack
      # response triple.
      def finish(outcome)
        outcome.is_a?(Array) ? outcome : redirect(outcome.to_s)
      end

      def redirect(url)
        response = Rack::Response.new
        response.redirect(url, 302)
        response.finish
      end

      def text(status, body)
        Rack::Response.new([body], status, { "content-type" => "text/plain" }).finish
      end

      def require_rack!
        require "rack"
      rescue LoadError
        raise NeonAPI::ConfigurationError,
              "the `rack` gem is required for NeonAPI::Auth::RackHandler. " \
              "Add `gem \"rack\"` to your Gemfile (Rails already includes it)."
      end
    end
  end
end
