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

      # White link with a soft danger outline
      def danger_outline
        render(UI::ButtonLink::Component.new(text: "Mark stolen", href: "#", color: :danger_outline))
      end

      # Filled purple primary
      def purple
        render(UI::ButtonLink::Component.new(text: "Purple Link", href: "#", color: :purple))
      end

      # White link with a purple outline (toggles to a purple tint when active)
      def purple_outline
        render(UI::ButtonLink::Component.new(text: "Purple outline", href: "#", color: :purple_outline))
      end

      def link
        render(UI::ButtonLink::Component.new(text: "Link style", href: "#", color: :link))
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
