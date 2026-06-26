# frozen_string_literal: true

RSpec.describe NeonAPI::Auth::Controller do
  let(:social)   { instance_double(NeonAPI::Auth::SocialAuth) }
  let(:verifier) { instance_double(NeonAPI::Auth::JWTVerifier) }

  # A minimal stand-in for a Rails controller: just the bits the concern uses,
  # plus injected Neon seams so we never touch the network or any_instance.
  let(:controller_class) do
    soc = social
    ver = verifier
    Class.new do
      include NeonAPI::Auth::Controller

      attr_reader :params, :session, :request, :redirects, :events

      def initialize(params: {}, session: {}, request: Object.new)
        @params = params
        @session = session
        @request = request
        @redirects = []
        @events = []
      end

      def redirect_to(url, **opts)
        @redirects << { url: url, opts: opts }
      end

      # Proves the app callbacks / callback_url run in controller context.
      def record(*args) = @events << args
      def callback_for_test = "https://app.example.com/auth/neon/callback"

      define_method(:neon_social) { soc }
      define_method(:neon_verifier) { ver }
    end
  end

  def configure(klass, **overrides)
    klass.neon_auth(
      callback_url: ->(_req) { callback_for_test },
      on_success: ->(claims) { record(:success, claims.sub) },
      on_failure: ->(error) { record(:failure, error.class) },
      **overrides
    )
  end

  describe "#neon_social_start" do
    let(:initiation) { NeonAPI::Auth::SocialAuth::Initiation.new(url: "https://neon/init?token=t", challenge: "ch-1") }

    before do
      configure(controller_class)
      allow(social).to receive(:sign_in).and_return(initiation)
    end

    it "initiates with the provider and the (request-derived) callback_url" do
      ctrl = controller_class.new(params: { provider: "google" }, session: {})
      ctrl.neon_social_start

      expect(social).to have_received(:sign_in).with(
        provider: "google",
        callback_url: "https://app.example.com/auth/neon/callback",
        error_callback_url: nil
      )
    end

    it "stashes the challenge and redirects to the provider URL" do
      ctrl = controller_class.new(params: { provider: "google" }, session: {})
      ctrl.neon_social_start

      expect(ctrl.session[:neon_auth_challenge]).to eq("ch-1")
      expect(ctrl.redirects.last).to eq(url: "https://neon/init?token=t", opts: { allow_other_host: true })
    end
  end

  describe "#neon_social_callback" do
    let(:result) { NeonAPI::Auth::SocialAuth::Result.new(jwt: "the.jwt", session_token: "st", session: nil) }
    let(:claims) { NeonAPI::Auth::Claims.new("sub" => "u-9", "email" => "ada@example.com") }

    before { configure(controller_class) }

    it "redeems, verifies, and runs on_success with the claims" do
      allow(social).to receive(:redeem_callback).and_return(result)
      allow(verifier).to receive(:verify).with("the.jwt").and_return(claims)

      ctrl = controller_class.new(params: { neon_auth_session_verifier: "V" },
                                  session: { neon_auth_challenge: "ch" })
      ctrl.neon_social_callback

      expect(social).to have_received(:redeem_callback).with(verifier: "V", challenge: "ch")
      expect(ctrl.events).to include([:success, "u-9"])
      expect(ctrl.session).not_to have_key(:neon_auth_challenge) # consumed
    end

    it "runs on_failure when redemption fails" do
      allow(social).to receive(:redeem_callback).and_raise(NeonAPI::Auth::SocialAuthError.new("expired"))

      ctrl = controller_class.new(params: { neon_auth_session_verifier: "V" },
                                  session: { neon_auth_challenge: "ch" })
      ctrl.neon_social_callback

      expect(ctrl.events.last).to eq([:failure, NeonAPI::Auth::SocialAuthError])
    end

    it "runs on_failure when JWT verification fails" do
      allow(social).to receive(:redeem_callback).and_return(result)
      allow(verifier).to receive(:verify).and_raise(NeonAPI::Auth::InvalidTokenError.new("bad"))

      ctrl = controller_class.new(params: { neon_auth_session_verifier: "V" }, session: {})
      ctrl.neon_social_callback

      expect(ctrl.events.last).to eq([:failure, NeonAPI::Auth::InvalidTokenError])
    end

    it "fails fast on a provider error param without redeeming" do
      allow(social).to receive(:redeem_callback)

      ctrl = controller_class.new(params: { error: "access_denied" }, session: { neon_auth_challenge: "ch" })
      ctrl.neon_social_callback

      expect(social).not_to have_received(:redeem_callback)
      expect(ctrl.events.last.first).to eq(:failure)
    end

    it "supports a zero-arity on_failure" do
      configure(controller_class, on_failure: -> { record(:failed) })
      allow(social).to receive(:redeem_callback).and_raise(NeonAPI::Auth::SocialAuthError.new("x"))

      ctrl = controller_class.new(params: {}, session: {})
      ctrl.neon_social_callback

      expect(ctrl.events.last).to eq([:failed])
    end
  end

  describe "seams" do
    it "raises a clear error if neon_auth was never configured" do
      bare = Class.new { include NeonAPI::Auth::Controller }
      ctrl = bare.new
      def ctrl.params = {}
      def ctrl.session = {}
      expect { ctrl.neon_social_start }.to raise_error(NeonAPI::ConfigurationError, /call `neon_auth/)
    end

    it "neon_find_user delegates to NeonAPI::Auth.find_user" do
      allow(NeonAPI::Auth).to receive(:find_user).and_return(:mapped_user)
      ctrl = controller_class.new
      expect(ctrl.neon_find_user(claims = double)).to eq(:mapped_user)
      expect(NeonAPI::Auth).to have_received(:find_user).with(claims)
    end

    it "uses NeonAPI::Auth.social / .verifier by default" do
      plain = Class.new { include NeonAPI::Auth::Controller }.new
      allow(NeonAPI::Auth).to receive_messages(social: :the_social, verifier: :the_verifier)
      expect(plain.neon_social).to eq(:the_social)
      expect(plain.neon_verifier).to eq(:the_verifier)
    end
  end
end
