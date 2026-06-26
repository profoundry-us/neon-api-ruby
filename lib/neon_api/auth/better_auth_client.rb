# frozen_string_literal: true

require_relative "rest_client"

module NeonAPI
  module Auth
    # Server-side client for a managed Neon Auth project's Better Auth REST API.
    #
    # Managed Neon Auth (the `better_auth` backend) is **not** an OIDC/OAuth2
    # provider: it exposes no OIDC discovery, `/authorize`, `/token` (OIDC), or
    # `/userinfo`, so the `omniauth_openid_connect` flow cannot complete against
    # it (see {NeonAPI::OmniAuth}). What it *does* expose is Better Auth's REST
    # API under the integration's `base_url` — which works server-side and is the
    # realistic path for a server-rendered Rails app:
    #
    # * `POST <base_url>/sign-up/email`
    # * `POST <base_url>/sign-in/email`  → sets a session cookie
    # * `GET  <base_url>/get-session`
    # * `GET  <base_url>/token`          → the EdDSA JWT {JWTVerifier} consumes
    # * `POST <base_url>/sign-out`
    # * `GET  <base_url>/ok`             (health)
    #
    # For social (OAuth) sign-in — "Continue with Google" — use {SocialAuth},
    # which builds on the same REST surface.
    #
    # The client keeps an in-memory cookie jar, so a sign-in followed by {#token}
    # on the same instance just works. To resume a session across requests (e.g.
    # from a value stored in the Rails session), set {#cookies=} / read
    # {#session_cookie}.
    #
    # @example Server-side password login in Rails
    #   ba = client.auth(project_id, branch_id).better_auth   # base_url from config
    #   ba.sign_in_email(email: params[:email], password: params[:password])
    #   claims = verifier.verify(ba.token)
    #   user = User.find_or_create_by!(neon_auth_id: claims.sub)
    class BetterAuthClient < RestClient
      # Register a new user with email + password.
      # @param email [String]
      # @param password [String]
      # @param name [String, nil]
      # @param extra [Hash] any additional Better Auth fields
      # @return [NeonAPI::Object] the parsed response
      def sign_up_email(email:, password:, name: nil, **extra)
        post("sign-up/email", { name: name, email: email, password: password }.compact.merge(extra))
      end

      # Sign in with email + password. On success the response sets a session
      # cookie, which this client captures for subsequent {#token}/{#session}.
      # @return [NeonAPI::Object]
      def sign_in_email(email:, password:, **extra)
        post("sign-in/email", { email: email, password: password }.merge(extra))
      end

      # The current session (requires an active session cookie).
      # @return [NeonAPI::Object, nil]
      def session
        get("get-session")
      end
      alias get_session session

      # Exchange the current session for a signed EdDSA JWT — the token
      # {JWTVerifier} verifies.
      # @return [String, nil] the JWT, or nil if none was returned
      def token
        result = get("token")
        result.is_a?(NeonAPI::Object) ? result["token"] : nil
      end

      # Sign out and clear the local cookie jar.
      # @return [NeonAPI::Object, nil]
      def sign_out
        result = post("sign-out", {})
        @cookies = {}
        result
      end

      # Health check (`GET /ok`).
      # @return [Boolean]
      def healthy?
        get("ok")
        true
      rescue NeonAPI::Error
        false
      end
    end
  end
end
