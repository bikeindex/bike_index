# frozen_string_literal: true

module UI
  module Tooltip
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      def with_block_content
        render(UI::Tooltip::Component.new(text: "5–9 mi")) do
          tag.i(class: "tw:block tw:h-5 tw:w-5 tw:cursor-help tw:rounded tw:bg-purple-400 tw:dark:bg-purple-700")
        end
      end

      def with_text_content
        render(UI::Tooltip::Component.new(text: "More information about this thing")) { "hover or focus me" }
      end

      def with_body_slot
        render(UI::Tooltip::Component.new) do |tooltip|
          tooltip.with_body { '<span class="tooltip-body-imperial">5 mi</span>'.html_safe }
          "body slot trigger"
        end
      end

      def with_tooltip_button_slot
        render(UI::Tooltip::Component.new(text: "Visible to other riders viewing your bike")) do |tooltip|
          tooltip.with_tooltip_button(
            class: "tw:inline-flex tw:items-center tw:justify-center tw:h-5 tw:w-5 tw:rounded-full " \
              "tw:bg-gray-200 tw:text-gray-700 tw:hover:bg-gray-300 " \
              "tw:dark:bg-gray-700 tw:dark:text-gray-200 tw:dark:hover:bg-gray-600 " \
              "tw:text-xs tw:font-bold tw:cursor-help " \
              "tw:focus:outline-none tw:focus:ring-3 tw:focus:ring-blue-500/40"
          ) { "?" }
        end
      end
      # @!endgroup
    end
  end
end
