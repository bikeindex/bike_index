# frozen_string_literal: true

module UI
  module Forms
    module RadioButtonGroup
      class Component < ApplicationComponent
        VARIANTS = %i[pills chips].freeze

        # Card-style chips (frame-size XS-XL style); the checked chip tints with the shared purple palette.
        CHIP_CLASSES = "tw:block tw:rounded-sm tw:border tw:border-gray-300 tw:bg-white tw:py-2 " \
          "tw:text-center tw:text-sm tw:font-medium tw:text-gray-700 " \
          "tw:peer-checked:border-purple-500 tw:peer-checked:bg-purple-100 tw:peer-checked:font-bold tw:peer-checked:text-purple-500 " \
          "tw:dark:border-gray-600 tw:dark:bg-gray-800 tw:dark:text-gray-300 " \
          "tw:dark:peer-checked:bg-purple-900 tw:dark:peer-checked:text-purple-300"

        def initialize(name:, entries:, selected: nil, form: nil, data: {}, variant: :pills)
          @name = name
          @entries = entries
          @selected = selected.to_s
          @form = form
          @data = data
          @variant = VARIANTS.include?(variant&.to_sym) ? variant.to_sym : :pills
        end

        def call
          return chips if @variant == :chips

          tag.div(class: "tw:flex tw:flex-wrap") do
            safe_join(@entries.each_with_index.map { |option, i|
              pill(option, first: i == 0, last: i == @entries.size - 1)
            })
          end
        end

        private

        def chips
          tag.div(class: "tw:flex tw:gap-2") do
            safe_join(@entries.map { |option| chip(option) })
          end
        end

        def chip(option)
          value = option[:value].to_s

          tag.label(class: "tw:flex-1 tw:cursor-pointer") do
            radio_button_tag(@name, value, value == @selected, class: "tw:peer tw:sr-only", form: @form, data: @data) +
              tag.span(option[:label].html_safe, class: CHIP_CLASSES)
          end
        end

        def pill(option, first:, last:)
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
          # Segments overlap by a pixel; z-index breaks the tie for it: hover/focus,
          # then checked, then the rest.
          tag.label(class: [
            "tw:relative tw:cursor-pointer tw:select-none tw:inline-flex tw:items-center tw:mb-0! tw:px-3 tw:py-1 tw:text-sm tw:leading-snug tw:transition-colors",
            "tw:text-gray-800 tw:bg-white tw:border tw:border-gray-200 tw:dark:bg-gray-800 tw:dark:text-gray-100 tw:dark:border-gray-700",
            "tw:hover:border-purple-500 tw:hover:bg-purple-50 tw:hover:z-20 tw:dark:hover:border-purple-500 tw:dark:hover:bg-purple-950",
            "tw:has-[:checked]:bg-purple-500 tw:has-[:checked]:text-white tw:has-[:checked]:border-purple-500",
            "tw:has-[:checked]:hover:bg-purple-500 tw:has-[:checked]:hover:border-purple-500",
            "tw:has-[:checked]:ring-2 tw:has-[:checked]:ring-purple-500/40 tw:has-[:checked]:z-10",
            "tw:has-[:focus-visible]:ring-2 tw:has-[:focus-visible]:ring-purple-500/40 tw:has-[:focus-visible]:ring-offset-1 tw:has-[:focus-visible]:z-20 tw:dark:has-[:focus-visible]:ring-offset-gray-900",
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
