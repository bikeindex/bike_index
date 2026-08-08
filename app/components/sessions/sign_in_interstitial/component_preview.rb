# frozen_string_literal: true

module Sessions
  module SignInInterstitial
    class ComponentPreview < ApplicationComponentPreview
      # auto_submit off, otherwise the preview posts itself away as soon as it renders
      def default
        render(Sessions::SignInInterstitial::Component.new(url: "#", fields: {token: "example-token"},
          auto_submit: false))
      end

      # Posts itself, at a token that's never valid — so it redirects back to the magic link
      # form rather than signing anyone in
      def auto_submitting
        render(Sessions::SignInInterstitial::Component.new(url: sign_in_with_magic_link_session_path,
          fields: {token: "not-a-real-token"}))
      end
    end
  end
end
