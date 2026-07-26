# frozen_string_literal: true

module UI
  module Button
    class ComponentPreview < ApplicationComponentPreview
      # @!group Colors
      def primary
        render(UI::Button::Component.new(text: "Primary", color: :primary))
      end

      def primary_active
        render(UI::Button::Component.new(text: "Primary Active", color: :primary, active: true))
      end

      # @label secondary (with data)
      def secondary
        render(UI::Button::Component.new(text: "Secondary", color: :secondary, data: {action: "click->ui--modal#open"}))
      end

      # @label secondary active (with data)
      def secondary_active
        render(UI::Button::Component.new(text: "Secondary Active", color: :secondary, active: true, data: {action: "click->ui--modal#open"}))
      end

      def error
        render(UI::Button::Component.new(text: "Delete", color: :error))
      end

      def error_active
        render(UI::Button::Component.new(text: "Error Active", color: :error, active: true))
      end

      # White button with a soft danger outline
      def danger_outline
        render(UI::Button::Component.new(text: "Mark stolen", color: :danger_outline))
      end

      def danger_outline_active
        render(UI::Button::Component.new(text: "Danger Outline Active", color: :danger_outline, active: true))
      end

      def link
        render(UI::Button::Component.new(text: "Link style", color: :link))
      end

      def link_active
        render(UI::Button::Component.new(text: "Link Active", color: :link, active: true))
      end

      # The redesign's quiet bold link (Where's my serial number?)
      def link_bold
        render(UI::Button::Component.new(text: "Where's my serial number?", color: :link, html_class: "tw:text-xs tw:font-bold"))
      end

      # Filled purple primary
      def purple
        render(UI::Button::Component.new(text: "Purple", color: :purple))
      end

      def purple_active
        render(UI::Button::Component.new(text: "Purple Active", color: :purple, active: true))
      end

      # White button with a purple outline (toggles to a purple tint when active)
      def purple_outline
        render(UI::Button::Component.new(text: "Purple outline", color: :purple_outline))
      end

      def purple_outline_active
        render(UI::Button::Component.new(text: "Purple Outline Active", color: :purple_outline, active: true))
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
