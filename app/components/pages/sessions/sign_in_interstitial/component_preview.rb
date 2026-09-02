# frozen_string_literal: true

module Pages
  module Sessions
    module SignInInterstitial
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Sessions::SignInInterstitial::Component.new(url: "#", fields: {token: "example-token"}))
        end

        def unsubscribing
          render(Pages::Sessions::SignInInterstitial::Component.new(url: "#",
            heading: "Confirm you want to unsubscribe", submit_text: "Unsubscribe"))
        end
      end
    end
  end
end
