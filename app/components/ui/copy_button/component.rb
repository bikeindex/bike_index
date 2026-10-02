# frozen_string_literal: true

module UI
  module CopyButton
    class Component < ApplicationComponent
      BUTTON_CLASS = "tw:group tw:shrink-0 tw:cursor-pointer tw:rounded-sm tw:p-1 " \
        "tw:text-gray-500 tw:hover:bg-gray-100 tw:hover:text-gray-900 " \
        "tw:dark:text-gray-400 tw:dark:hover:bg-gray-700 tw:dark:hover:text-gray-100 " \
        "tw:focus:ring-2 tw:focus:ring-gray-400"

      def initialize(value:, label:)
        @value = value
        @label = label
      end

      def call
        tag.button(type: "button", class: BUTTON_CLASS, title: @label,
          data: {controller: "ui--copy-button", "ui--copy-button-text-value": @value, action: "ui--copy-button#copy"}) do
          safe_join([
            helpers.inline_svg_tag("icons/copy.svg", class: "tw:h-3.5 tw:w-3.5 tw:group-data-copied:hidden", aria_hidden: true),
            helpers.inline_svg_tag("icons/check.svg", class: "tw:hidden tw:h-3.5 tw:w-3.5 tw:text-green-600 tw:group-data-copied:block", aria_hidden: true)
          ])
        end
      end
    end
  end
end
