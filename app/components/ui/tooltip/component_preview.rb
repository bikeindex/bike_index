# frozen_string_literal: true

module UI
  module Tooltip
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      def multiple
        render_with_template(template: "ui/tooltip/preview/multiple")
      end

      def with_tooltip_button_slot
        render(UI::Tooltip::Component.new(text: "Custom trigger element via slot")) do |tooltip|
          tooltip.with_tooltip_button(
            class: "tw:px-2 tw:py-1 tw:rounded tw:bg-gray-200 tw:dark:bg-gray-700",
            data: {action: "click->custom#noop"}
          )
        end
      end
      # @!endgroup
    end
  end
end
