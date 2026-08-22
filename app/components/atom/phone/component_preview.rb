# frozen_string_literal: true

module Atom
  module Phone
    # @label Phone
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      # @param phone text "Phone to render"
      def default(phone: "999 999 9999")
        render(Atom::Phone::Component.new(phone:))
      end

      # @label with a country code and an extension
      def with_country_code_and_extension
        render(Atom::Phone::Component.new(phone: "+91 8041505583 x2929"))
      end

      # @label plain text, not a tel: link
      def skip_link
        render(Atom::Phone::Component.new(phone: "999 999 9999", skip_link: true))
      end
      # @!endgroup
    end
  end
end
