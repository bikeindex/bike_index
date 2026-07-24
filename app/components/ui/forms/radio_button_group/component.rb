# frozen_string_literal: true

module UI
  module Forms
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

          # Mirrors UI::Button color: :purple_outline (resting + active), driving the
          # active state off the checked radio so the two stay visually in lockstep.
          tag.label(class: [
            "tw:cursor-pointer tw:select-none tw:inline-flex tw:items-center tw:mb-0! tw:px-3 tw:py-1 tw:text-sm tw:leading-snug tw:transition-colors",
            "tw:text-gray-800 tw:bg-white tw:border tw:border-gray-200 tw:dark:bg-gray-800 tw:dark:text-gray-100 tw:dark:border-gray-700",
            "tw:hover:border-[#715eb2] tw:hover:bg-[#f7f5fc] tw:dark:hover:border-[#715eb2] tw:dark:hover:bg-purple-950",
            "tw:has-[:checked]:bg-[#715eb2] tw:has-[:checked]:text-white tw:has-[:checked]:border-[#715eb2]",
            "tw:has-[:checked]:hover:bg-[#715eb2] tw:has-[:checked]:hover:border-[#715eb2]",
            "tw:has-[:focus-visible]:ring-2 tw:has-[:focus-visible]:ring-[#715eb2]/40 tw:has-[:focus-visible]:ring-offset-1 tw:dark:has-[:focus-visible]:ring-offset-gray-900",
            round, border_l
          ].join(" ")) do
            radio_button_tag(@name, value, checked,
              class: "tw:sr-only",
              form: @form,
              data: @data) +
              tag.span(option[:label].html_safe)
          end
        end
      end
    end
  end
end
