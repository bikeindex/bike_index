# frozen_string_literal: true

module UI
  module CopyButton
    # `tooltip`, its label and value show in a tooltip, "Copy ID (m/trek/2025/fetch)", rather than its title
    class Component < ApplicationComponent
      BUTTON_CLASS = "tw:group tw:shrink-0 tw:cursor-pointer tw:rounded-sm tw:p-1 " \
        "tw:text-gray-500 tw:hover:bg-gray-100 tw:hover:text-gray-900 " \
        "tw:dark:text-gray-400 tw:dark:hover:bg-gray-700 tw:dark:hover:text-gray-100 " \
        "tw:focus:ring-2 tw:focus:ring-gray-400"

      def initialize(value:, label:, tooltip: false)
        @value = value
        @label = label
        @tooltip = tooltip
      end

      def call
        return tag.button(icons, type: "button", class: BUTTON_CLASS, title: @label, data:) unless @tooltip

        render(UI::Tooltip::Component.new(text: "#{@label} (#{@value})")) do |tooltip|
          tooltip.with_body { safe_join([@label, " (", tag.code(@value, class: "tw:font-mono"), ")"]) }
          tooltip.with_tooltip_button(class: BUTTON_CLASS, data:) { icons }
        end
      end

      private

      def data = {controller: "ui--copy-button", "ui--copy-button-text-value": @value, action: "ui--copy-button#copy"}

      def icons
        safe_join([
          helpers.inline_svg_tag("icons/copy.svg", class: "tw:size-3.5 tw:group-data-copied:hidden", aria_hidden: true),
          helpers.inline_svg_tag("icons/check.svg", class: "tw:hidden tw:size-3.5 tw:text-green-600 tw:group-data-copied:block", aria_hidden: true)
        ])
      end
    end
  end
end
