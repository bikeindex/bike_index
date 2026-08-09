# frozen_string_literal: true

module UI
  module Button
    class ComponentPreview < ApplicationComponentPreview
      # @!group In form
      # Submit reveals the spinner and disables the button -- but only once native
      # validation has passed, so an empty email leaves the button alone
      def in_form
        {template: "ui/button/component_preview/in_form"}
      end

      # The same state without the submit
      def submitting
        render(UI::Button::Component.new(text: "Next", color: :primary, type: "submit",
          spinner: true, disabled: true, html_class: "tw:[&_span]:inline-flex!"))
      end
      # @!endgroup

      # @!group Colors
      def primary
        render(UI::Button::Component.new(text: "Primary", color: :primary))
      end

      def primary_active
        render(UI::Button::Component.new(text: "Primary Active", color: :primary, active: true))
      end

      def primary_disabled
        render(UI::Button::Component.new(text: "Primary Disabled", color: :primary, disabled: true))
      end

      # White button with a purple outline (fills purple when active)
      # @label secondary (with data)
      def secondary
        render(UI::Button::Component.new(text: "Secondary", color: :secondary, data: {action: "click->ui--modal#open"}))
      end

      # @label secondary active (with data)
      def secondary_active
        render(UI::Button::Component.new(text: "Secondary Active", color: :secondary, active: true, data: {action: "click->ui--modal#open"}))
      end

      def secondary_disabled
        render(UI::Button::Component.new(text: "Secondary Disabled", color: :secondary, disabled: true))
      end

      # White button with a soft danger outline
      def error
        render(UI::Button::Component.new(text: "Delete", color: :error))
      end

      def error_active
        render(UI::Button::Component.new(text: "Error Active", color: :error, active: true))
      end

      def error_disabled
        render(UI::Button::Component.new(text: "Error Disabled", color: :error, disabled: true))
      end

      def link
        render(UI::Button::Component.new(text: "Link style", color: :link))
      end

      def link_active
        render(UI::Button::Component.new(text: "Link Active", color: :link, active: true))
      end

      def link_disabled
        render(UI::Button::Component.new(text: "Link Disabled", color: :link, disabled: true))
      end

      # Filled purple primary
      def purple
        render(UI::Button::Component.new(text: "Purple", color: :purple))
      end

      def purple_active
        render(UI::Button::Component.new(text: "Purple Active", color: :purple, active: true))
      end

      def purple_disabled
        render(UI::Button::Component.new(text: "Purple Disabled", color: :purple, disabled: true))
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
