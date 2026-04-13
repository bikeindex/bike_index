# frozen_string_literal: true

module Form
  module RadioButtonGroup
    class Component < ApplicationComponent
      def initialize(name:, entries:, selected: nil, form: nil, data: {})
        @name = name
        @entries = entries
        @selected = selected.to_s
        @form = form
        @data = data
      end

      def call
        tag.div(class: "tw:flex tw:flex-wrap") do
          safe_join(@entries.each_with_index.map { |option, i|
            radio_button(option, first: i == 0, last: i == @entries.size - 1)
          })
        end
      end

      private

      def radio_button(option, first:, last:)
        value = option[:value].to_s
        checked = value == @selected

        round = if first
          "tw:rounded-l"
        elsif last
          "tw:rounded-r"
        else
          ""
        end
        border_l = first ? "" : "tw:-ml-px"

        tag.label(class: [
          "tw:cursor-pointer tw:select-none tw:inline-flex tw:items-center tw:mb-0!",
          "tw:bg-white tw:dark:bg-gray-800 tw:border tw:border-gray-300 tw:dark:border-gray-600 tw:px-3 tw:py-1 tw:text-sm tw:leading-snug",
          "tw:transition-colors tw:has-[:checked]:bg-gray-700 tw:has-[:checked]:text-white tw:has-[:checked]:border-gray-700",
          "tw:dark:has-[:checked]:bg-gray-300 tw:dark:has-[:checked]:text-gray-900 tw:dark:has-[:checked]:border-gray-300",
          "tw:hover:bg-gray-100 tw:has-[:checked]:hover:bg-gray-700",
          "tw:dark:hover:bg-gray-700 tw:dark:has-[:checked]:hover:bg-gray-300",
          "tw:has-[:focus-visible]:ring-2 tw:has-[:focus-visible]:ring-blue-500 tw:has-[:focus-visible]:ring-offset-1",
          "tw:dark:has-[:focus-visible]:ring-blue-400 tw:dark:has-[:focus-visible]:ring-offset-gray-900",
          round, border_l
        ].join(" ")) do
          radio_button_tag(@name, value, checked,
            class: "tw:sr-only",
            form: @form,
            data: @data) +
            option[:label].html_safe
        end
      end
    end
  end
end
