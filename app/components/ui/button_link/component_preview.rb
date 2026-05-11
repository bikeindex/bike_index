# frozen_string_literal: true

module UI
  module ButtonLink
    class ComponentPreview < ApplicationComponentPreview
      # @!group Colors
      def primary
        render(UI::ButtonLink::Component.new(text: "Primary Link", href: "#", color: :primary))
      end

      def secondary
        render(UI::ButtonLink::Component.new(text: "Secondary Link", href: "#", color: :secondary))
      end

      def error
        render(UI::ButtonLink::Component.new(text: "Error Link", href: "#", color: :error))
      end
      # @!endgroup

      # @!group States
      def active
        render(UI::ButtonLink::Component.new(text: "Active Link", href: "#", color: :primary, active: true))
      end

      def with_data_attribute
        render(UI::ButtonLink::Component.new(text: "Turbo Link", href: "#", data: {turbo: false}))
      end
      # @!endgroup
    end
  end
end
