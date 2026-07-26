# frozen_string_literal: true

module UI
  module Forms
    module RadioButtonGroup
      class Component < ApplicationComponent
        # Mirrors UI::Button color: :purple_outline (resting + active), driving the
        # active state off the checked radio so the two stay visually in lockstep.
        CHIP_CLASSES = [
          "tw:cursor-pointer tw:select-none tw:inline-flex tw:items-center tw:justify-center tw:mb-0! tw:rounded tw:px-3 tw:py-1 tw:text-sm tw:leading-snug tw:transition-colors",
          "tw:text-gray-800 tw:bg-white tw:border tw:border-gray-200 tw:dark:bg-gray-800 tw:dark:text-gray-100 tw:dark:border-gray-700",
          "tw:hover:border-purple-500 tw:hover:bg-purple-50 tw:dark:hover:border-purple-500 tw:dark:hover:bg-purple-950",
          "tw:has-[:checked]:bg-purple-500 tw:has-[:checked]:text-white tw:has-[:checked]:border-purple-500",
          "tw:has-[:checked]:hover:bg-purple-500 tw:has-[:checked]:hover:border-purple-500",
          "tw:has-[:checked]:ring-2 tw:has-[:checked]:ring-purple-500/40",
          "tw:has-[:focus-visible]:outline-none tw:has-[:focus-visible]:ring-3 tw:has-[:focus-visible]:ring-purple-500/40"
        ].join(" ").freeze

        # min-w-fit is what lets a full-width row wrap: flex-1 alone resolves every
        # chip to a zero basis, so they'd shrink past their labels instead of breaking.
        FULL_WIDTH_CLASSES = "tw:flex-1 tw:min-w-fit"

        # full_width: chips share the row evenly (the frame-size XS-XL selector),
        # rather than each taking only the width of its label.
        def initialize(name:, entries:, selected: nil, form: nil, data: {}, full_width: false)
          @name = name
          @entries = entries
          @selected = selected.to_s
          @form = form
          @data = data
          @full_width = full_width
        end

        def call
          tag.div(class: "tw:flex tw:flex-wrap tw:gap-2") do
            safe_join(@entries.map { |option| chip(option) })
          end
        end

        private

        def chip(option)
          value = option[:value].to_s

          tag.label(class: [CHIP_CLASSES, (FULL_WIDTH_CLASSES if @full_width)].compact.join(" ")) do
            radio_button_tag(@name, value, value == @selected, class: "tw:sr-only", form: @form, data: @data) +
              tag.span(option[:label].html_safe)
          end
        end
      end
    end
  end
end
