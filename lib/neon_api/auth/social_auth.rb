# frozen_string_literal: true

require_relative "rest_client"

module NeonAPI
  module Auth
    # Raised when a social (OAuth) sign-in can't be initiated or the callback
    # handoff can't be redeemed (e.g. an expired, already-used, or invalid
    # `neon_auth_session_verifier`).
    class SocialAuthError < NeonAPI::Error; end

    # Server-side social (OAuth) sign-in for managed Neon Auth — "Continue with
    # Google" for a server-rendered Rails app, with no Node sidecar and no
    # client-side JS.
    #
    # Managed Neon Auth hands a completed social sign-in back to your app as an
    # encrypted, one-time `neon_auth_session_verifier`. The catch (confirmed
    # against a live project) is that the verifier alone is not enough: redeeming
    # it also requires the **challenge cookie** that Neon sets when the flow is
    # initiated. This class carries that challenge for you, so the flow is two
    # server-side steps with the challenge round-tripped through your own session
    # store (e.g. the Rails session) — no reverse proxy and no cookie secret.
    #
    # ## Flow
    #
    # 1. **Initiate.** {#sign_in} calls `POST <base_url>/sign-in/social` and
    #    returns the provider URL to redirect the browser to, plus an opaque
    #    `challenge` string. Stash the challenge (e.g. `session[:neon_challenge]`)
    #    and redirect to the URL.
    # 2. **Browser → provider → Neon.** The user approves at the provider; Neon
    #    creates the session and redirects back to your `callback_url` with
    #    `?neon_auth_session_verifier=<token>`.
    # 3. **Redeem.** {#redeem_callback} exchanges that verifier (+ the stashed
    #    challenge) for the session and an EdDSA JWT, which you verify with
    #    {JWTVerifier} exactly like the email/password flow.
    #
    # @note The `callback_url`'s host must be allow-listed in the Neon Console
    #   (Auth → Configuration → Domains); otherwise the browser redirect after
    #   consent won't reach your app. Redemption itself does not depend on it.
    #
    # @example Rails: two routes
    #   # GET /auth/neon/start
    #   social = client.auth(project_id, branch_id).social
    #   init = social.sign_in(provider: "google",
    #                         callback_url: "https://app.example.com/auth/neon/callback")
    #   session[:neon_challenge] = init.challenge
    #   redirect_to init.url, allow_other_host: true
    #
    #   # GET /auth/neon/callback?neon_auth_session_verifier=...
    #   result = social.redeem_callback(verifier:  params[:neon_auth_session_verifier],
    #                                   challenge: session.delete(:neon_challenge))
    #   claims = verifier.verify(result.jwt)
    #   user = User.find_or_create_by!(neon_auth_id: claims.sub)
    class SocialAuth < RestClient
      # The result of {#sign_in}: where to send the browser, and the opaque
      # challenge to stash until the callback.
      Initiation = Struct.new(:url, :challenge, keyword_init: true)

      # The result of {#redeem_callback}: the EdDSA JWT (verify with
      # {JWTVerifier}), the session cookie for resuming the Neon session, and the
      # raw session/user payload (`session.user.id == neon_auth.user.id`).
      Result = Struct.new(:jwt, :session_token, :session, keyword_init: true)

      # Initiate a social sign-in.
      #
      # @param provider [String] e.g. "google", "github", "microsoft"
      # @param callback_url [String] the URL Neon redirects back to after consent
      #   (its host must be allow-listed in the Neon Console)
      # @param error_callback_url [String, nil] where Neon redirects on error
      #   (defaults to `callback_url`)
      # @param extra [Hash] any additional `/sign-in/social` body fields
      # @return [Initiation]
      # @raise [SocialAuthError] if no sign-in URL is returned
      def sign_in(provider:, callback_url:, error_callback_url: nil, **extra)
        raise ArgumentError, "provider is required" if blank?(provider)
        raise ArgumentError, "callback_url is required" if blank?(callback_url)

        body = {
          provider: provider,
          callbackURL: callback_url,
          errorCallbackURL: error_callback_url || callback_url
        }.merge(extra)

        response = post("sign-in/social", body)
        url = response.is_a?(NeonAPI::Object) ? response["url"] : nil
        raise SocialAuthError, "Neon Auth did not return a social sign-in URL" if blank?(url)

        Initiation.new(url: url, challenge: session_cookie)
      end

      # Redeem the callback handoff into a verified session + JWT.
      #
      # @param verifier [String] the `neon_auth_session_verifier` query value from
      #   the callback
      # @param challenge [String] the opaque challenge returned by {#sign_in}
      # @return [Result]
      # @raise [SocialAuthError] if the verifier can't be redeemed (expired,
      #   already used, or invalid), or no JWT is issued
      def redeem_callback(verifier:, challenge:)
        raise ArgumentError, "verifier is required" if blank?(verifier)
        raise ArgumentError, "challenge is required" if blank?(challenge)

        # Present the challenge cookie and the verifier to get-session; on success
        # Neon returns the session and sets the real session_token cookie (which
        # the jar captures for the token call below).
        self.cookies = challenge
        session = get("get-session", query: { "neon_auth_session_verifier" => verifier })
        unless session.is_a?(NeonAPI::Object) && !blank?(session["user"])
          raise SocialAuthError,
                "could not redeem the session verifier (it may be expired, already used, or invalid)"
        end

        jwt = fetch_jwt
        raise SocialAuthError, "redeemed the session but no JWT was issued" if blank?(jwt)

        Result.new(jwt: jwt, session_token: session_token_cookie, session: session)
      end

      private

      def fetch_jwt
        result = get("token")
        result.is_a?(NeonAPI::Object) ? result["token"] : nil
      end

      # The captured session-token cookie as a "name=value" string, for resuming
      # the Neon session later (e.g. via BetterAuthClient#cookies=).
      def session_token_cookie
        name, value = cookies.find { |cookie_name, _| cookie_name.include?("session_token") }
        name && "#{name}=#{value}"
      end

      def blank?(value)
        value.nil? || value.to_s.empty?
      end
    end
  end
end
