# frozen_string_literal: true

module UI
  module CallToActionBanner
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(UI::CallToActionBanner::Component.new(heading: "Members keep Bike Index free",
          subheading: "Join thousands of riders who fund the registry")) { button }
      end

      def without_illustration
        render(UI::CallToActionBanner::Component.new(heading: "Every hour it sits unregistered, it gets harder to find",
          illustration: false)) { button }
      end

      private

      def button
        render(UI::ButtonLink::Component.new(href: "#", text: "Join now", color: :yellow, size: :callout))
      end
    end
  end
end
