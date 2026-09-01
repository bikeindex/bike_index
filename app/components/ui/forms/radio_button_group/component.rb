# frozen_string_literal: true

module UI
  module Forms
    module RadioButtonGroup
      class Component < ApplicationComponent
        # The chip is UI::Button's secondary, so the two chip groups can't drift
        # apart. Only checked and focus have to be restated, since those hang off
        # the radio rather than the label's own :checked/:focus.
        CHIP_CLASSES = [
          UI::Button::Component.build_classes(color: :secondary, size: :sm),
          "tw:mb-0", # the chip is a <label>, which legacy CSS gives a bottom margin
          "tw:has-[:checked]:bg-purple-500 tw:has-[:checked]:text-white tw:has-[:checked]:border-purple-500",
          # A <label> is never :disabled — these carry the specificity to beat the hover
          # they override, which is guarded not-disabled:not-aria-disabled:
          "tw:has-[:checked]:not-disabled:not-aria-disabled:hover:bg-purple-500 tw:has-[:checked]:not-disabled:not-aria-disabled:hover:border-purple-500",
          "tw:has-[:checked]:ring-2 tw:has-[:checked]:ring-purple-500/40",
          "tw:has-[:focus-visible]:outline-none tw:has-[:focus-visible]:ring-3 tw:has-[:focus-visible]:ring-purple-500/40"
        ].join(" ").freeze

        # full_width: chips share the row evenly (the frame-size XS-XL selector),
        # rather than each taking only the width of its label.
        def initialize(name:, entries:, selected: nil, form: nil, full_width: false, data: {})
          @name = name
          @entries = entries
          @selected = selected.to_s
          @form = form
          @full_width = full_width
          @data = data
        end

        def call
          tag.div(class: UI::ButtonGroup::Component.layout_classes(full_width: @full_width)) do
            safe_join(@entries.map { |option| chip(option) })
          end
        end

        private

        def chip(option)
          value = option[:value].to_s

          tag.label(class: CHIP_CLASSES) do
            radio_button_tag(@name, value, value == @selected, class: "tw:sr-only", form: @form, data: @data) +
              tag.span(option[:label].html_safe)
          end
        end
      end
    end
  end
end
