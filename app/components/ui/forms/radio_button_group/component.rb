# frozen_string_literal: true

module UI
  module Forms
    module RadioButtonGroup
      class Component < ApplicationComponent
        # Only checked and focus are restated, since those hang off the radio
        # rather than the <label> the chip classes land on.
        CHIP_CLASSES = [
          UI::ButtonGroup::Component::CHIP_CLASSES,
          "tw:mb-0", # the chip is a <label>, which legacy CSS gives a bottom margin
          "tw:has-[:checked]:bg-purple-500 tw:has-[:checked]:text-white tw:has-[:checked]:border-purple-500",
          # A <label> is never :disabled — these carry the specificity to beat the hover
          # they override, which is guarded not-disabled:not-aria-disabled:
          "tw:has-[:checked]:not-disabled:not-aria-disabled:hover:bg-purple-500 tw:has-[:checked]:not-disabled:not-aria-disabled:hover:border-purple-500",
          "tw:has-[:checked]:ring-2 tw:has-[:checked]:ring-purple-500/40",
          "tw:has-[:focus-visible]:outline-none tw:has-[:focus-visible]:ring-3 tw:has-[:focus-visible]:ring-purple-500/40"
        ].join(" ").freeze

        SEGMENT_CLASSES = [
          UI::ButtonGroup::Component::SEGMENT_CLASSES,
          "tw:mb-0",
          "tw:has-[:checked]:bg-white tw:has-[:checked]:text-gray-900 tw:has-[:checked]:shadow-sm",
          "tw:has-[:checked]:dark:bg-gray-900 tw:has-[:checked]:dark:text-gray-100",
          "tw:has-[:focus-visible]:outline-none tw:has-[:focus-visible]:ring-3 tw:has-[:focus-visible]:ring-purple-500/40"
        ].join(" ").freeze

        # full_width: chips share the row evenly (the frame-size XS-XL selector),
        # rather than each taking only the width of its label.
        # kind: :toggle renders UI::ButtonGroup's segmented control, with a radio per segment
        def initialize(name:, entries:, selected: nil, form: nil, full_width: false, kind: :button, data: {})
          raise ArgumentError, "unknown kind #{kind.inspect}, expected one of: #{UI::ButtonGroup::Component::KINDS.join(", ")}" unless UI::ButtonGroup::Component::KINDS.include?(kind)
          raise ArgumentError, "full_width is not supported for the toggle kind" if full_width && kind == :toggle

          @name = name
          @entries = entries
          @selected = selected.to_s
          @form = form
          @full_width = full_width
          @kind = kind
          @data = data
        end

        def call
          tag.div(class: group_classes) do
            safe_join(@entries.map { |option| chip(option) })
          end
        end

        private

        def toggle? = @kind == :toggle

        def group_classes = toggle? ? UI::ButtonGroup::Component::TRACK_CLASSES : UI::ButtonGroup::Component.layout_classes(full_width: @full_width)

        def chip(option)
          value = option[:value].to_s

          tag.label(class: toggle? ? SEGMENT_CLASSES : CHIP_CLASSES) do
            radio_button_tag(@name, value, value == @selected, class: "tw:sr-only", form: @form, data: @data) +
              tag.span(option[:label].html_safe)
          end
        end
      end
    end
  end
end
