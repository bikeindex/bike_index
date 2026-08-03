# frozen_string_literal: true

module Sessions
  module SignInInterstitial
    class ComponentPreview < ApplicationComponentPreview
      # auto_submit off, otherwise the preview posts itself away as soon as it renders
      def default
        render(Sessions::SignInInterstitial::Component.new(url: "#", fields: {token: "example-token"},
          auto_submit: false))
      end
    end
  end
end
