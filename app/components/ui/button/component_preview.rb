# frozen_string_literal: true

module UI
  module Button
    class ComponentPreview < ApplicationComponentPreview
      # @label legacy (using twbtn classes)
      def legacy
        {template: "ui/button/component_preview/default"}
      end

      # @!group Colors
      def primary
        render(UI::Button::Component.new(text: "Primary", color: :primary))
      end

      def secondary
        render(UI::Button::Component.new(text: "Secondary", color: :secondary))
      end

      def error
        render(UI::Button::Component.new(text: "Delete", color: :error))
      end

      def link
        render(UI::Button::Component.new(text: "Link style", color: :link))
      end

      def secondary_with_data
        render(UI::Button::Component.new(text: "Secondary with data", color: :secondary, data: {action: "click->ui--modal#open"}))
      end
      # @!endgroup

      # @!group Active
      def primary_active
        render(UI::Button::Component.new(text: "Primary Active", color: :primary, active: true))
      end

      def secondary_active
        render(UI::Button::Component.new(text: "Secondary Active", color: :secondary, active: true))
      end

      def error_active
        render(UI::Button::Component.new(text: "Error Active", color: :error, active: true))
      end

      def link_active
        render(UI::Button::Component.new(text: "Link Active", color: :link, active: true))
      end
      # @!endgroup

      # @!group Sizes
      def small
        render(UI::Button::Component.new(text: "Small", size: :sm))
      end

      def medium
        render(UI::Button::Component.new(text: "Medium", size: :md))
      end

      def large
        render(UI::Button::Component.new(text: "Large", size: :lg))
      end

      def large_with_icon
        render(UI::Button::Component.new(size: :lg)) do
          '<svg class="tw:w-5 tw:h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg> Add Item'.html_safe
        end
      end
      # @!endgroup
    end
  end
end
