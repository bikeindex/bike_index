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

      # @!group button_to (form submit)
      # @label button_to POST
      def button_to_post
        render(UI::ButtonLink::Component.new(text: "Follow", href: "#", color: :primary, method: :post))
      end

      # @label button_to DELETE
      def button_to_delete
        render(UI::ButtonLink::Component.new(text: "Delete", href: "#", color: :error, method: :delete))
      end
      # @!endgroup
    end
  end
end
