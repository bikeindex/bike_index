# frozen_string_literal: true

module Sessions
  module SignInInterstitial
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(Sessions::SignInInterstitial::Component.new(url: "#", fields: {token: "example-token"}))
      end

      # Posts itself, at a token that's never valid — so it redirects back to the magic link
      # form rather than signing anyone in. That path is rack_attack throttled, so reloading
      # this preview repeatedly will 429 the auth endpoints for a minute
      def auto_submitting
        render(Sessions::SignInInterstitial::Component.new(url: sign_in_with_magic_link_session_path,
          fields: {token: "not-a-real-token"}, auto_submit: true))
      end
    end
  end
end
