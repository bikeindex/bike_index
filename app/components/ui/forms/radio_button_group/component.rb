# frozen_string_literal: true

module UI
  module Forms
    module RadioButtonGroup
      class Component < ApplicationComponent
        # Template Dependency: UI::ButtonGroup::Component
        # A <label> never takes focus, so the ring hangs off the radio inside it
        LABEL_CLASSES = [
          "tw:mb-0", # a <label>, which legacy CSS gives a bottom margin
          "tw:has-[:focus-visible]:outline-none tw:has-[:focus-visible]:ring-3 tw:has-[:focus-visible]:ring-purple-500/40"
        ].join(" ").freeze

        CHIP_CLASSES = [UI::ButtonGroup::Component::CHIP_CLASSES, LABEL_CLASSES].join(" ").freeze

        SEGMENT_CLASSES = [UI::ButtonGroup::Component::SEGMENT_CLASSES, LABEL_CLASSES].join(" ").freeze

        # full_width: chips share the row evenly (the frame-size XS-XL selector),
        # rather than each taking only the width of its label.
        # kind: :toggle renders UI::ButtonGroup's segmented control, with a radio per segment.
        # html_options go on each radio
        def initialize(name:, entries:, selected: nil, full_width: false, kind: :button, html_options: {})
          @group_classes = UI::ButtonGroup::Component.group_classes(kind:, full_width:)
          @label_classes = (kind == :toggle) ? SEGMENT_CLASSES : CHIP_CLASSES
          @name = name
          @entries = entries
          @selected = selected.to_s
          @html_options = html_options.merge(class: ["tw:sr-only", html_options[:class]].compact.join(" "))
        end

        def call
          tag.div(class: @group_classes) do
            safe_join(@entries.map { |option| chip(option) })
          end
        end

        private

        def chip(option)
          value = option[:value].to_s

          tag.label(class: @label_classes) do
            radio_button_tag(@name, value, value == @selected, @html_options) +
              tag.span(option[:label].html_safe)
          end
        end
      end
    end
  end
end
