# frozen_string_literal: true

module UI
  module ButtonTo
    class ComponentPreview < ApplicationComponentPreview
      # @!group Colors
      def primary
        render(UI::ButtonTo::Component.new(text: "Primary", href: "#", color: :primary))
      end

      def secondary
        render(UI::ButtonTo::Component.new(text: "Secondary", href: "#", color: :secondary))
      end

      def error
        render(UI::ButtonTo::Component.new(text: "Delete", href: "#", color: :error))
      end
      # @!endgroup

      # @!group States
      def active
        render(UI::ButtonTo::Component.new(text: "Active", href: "#", color: :primary, active: true))
      end

      # @label put (renders a hidden _method field)
      def with_put_method
        render(UI::ButtonTo::Component.new(text: "Update", href: "#", color: :error, method: :put))
      end
      # @!endgroup
    end
  end
end
