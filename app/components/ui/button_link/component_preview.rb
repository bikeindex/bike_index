# frozen_string_literal: true

module UI
  module ButtonLink
    class ComponentPreview < ApplicationComponentPreview
      # @!group Colors
      def primary
        render(UI::ButtonLink::Component.new(text: "Primary Link", href: "#", color: :primary))
      end

      def primary_active
        render(UI::ButtonLink::Component.new(text: "Primary Active", href: "#", color: :primary, active: true))
      end

      # White link with a purple outline (fills purple when active)
      def secondary
        render(UI::ButtonLink::Component.new(text: "Secondary Link", href: "#", color: :secondary))
      end

      def secondary_active
        render(UI::ButtonLink::Component.new(text: "Secondary Active", href: "#", color: :secondary, active: true))
      end

      def error
        render(UI::ButtonLink::Component.new(text: "Error Link", href: "#", color: :error))
      end

      def error_active
        render(UI::ButtonLink::Component.new(text: "Error Active", href: "#", color: :error, active: true))
      end

      # White link with a soft danger outline
      def danger_outline
        render(UI::ButtonLink::Component.new(text: "Mark stolen", href: "#", color: :danger_outline))
      end

      def danger_outline_active
        render(UI::ButtonLink::Component.new(text: "Danger Outline Active", href: "#", color: :danger_outline, active: true))
      end

      def link
        render(UI::ButtonLink::Component.new(text: "Link style", href: "#", color: :link))
      end

      def link_active
        render(UI::ButtonLink::Component.new(text: "Link Active", href: "#", color: :link, active: true))
      end

      # Filled purple primary
      def purple
        render(UI::ButtonLink::Component.new(text: "Purple Link", href: "#", color: :purple))
      end

      def purple_active
        render(UI::ButtonLink::Component.new(text: "Purple Active", href: "#", color: :purple, active: true))
      end
      # @!endgroup

      # @!group States
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
