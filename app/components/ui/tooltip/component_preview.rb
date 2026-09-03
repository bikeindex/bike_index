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

      # No trigger block: renders the default "?" button
      def default_button
        render(UI::Tooltip::Component.new(text: "Visible to other riders viewing your bike"))
      end

      # A link in the popup: click the "?" to keep it open, then click the link
      def with_interactive_body
        render(UI::Tooltip::Component.new(text: "current commit: a1b2c3d")) do |tooltip|
          tooltip.with_body do
            'current commit: <a href="https://github.com/bikeindex/bike_index/commit/a1b2c3d" class="twlink">a1b2c3d</a>'.html_safe
          end
        end
      end
      # @!endgroup
    end
  end
end
