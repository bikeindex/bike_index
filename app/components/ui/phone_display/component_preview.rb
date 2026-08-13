# frozen_string_literal: true

module UI
  module PhoneDisplay
    class ComponentPreview < ApplicationComponentPreview
      # @!group Phone Variants
      # @param phone text "Phone to render"
      def default(phone: "999 999 9999")
        render(UI::PhoneDisplay::Component.new(phone:))
      end

      def with_country_code_and_extension
        render(UI::PhoneDisplay::Component.new(phone: "+91 8041505583 x2929"))
      end

      def skip_link
        render(UI::PhoneDisplay::Component.new(phone: "999 999 9999", skip_link: true))
      end
      # @!endgroup
    end
  end
end
