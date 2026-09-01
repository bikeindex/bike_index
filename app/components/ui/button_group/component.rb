# frozen_string_literal: true

module UI
  module ButtonGroup
    # A row of chips that navigate or act — the link/button counterpart of
    # UI::Forms::RadioButtonGroup, which builds its <label> chips off the same
    # UI::Button styling.
    class Component < ApplicationComponent
      CHIP_CLASSES = UI::Button::Component.build_classes(color: :secondary, size: :sm).freeze

      # full_width lays the chips out as equal columns that wrap, staying the same width
      # on every line — flex would size each line independently. auto-fit needs a
      # definite minimum to count repetitions.
      def self.layout_classes(full_width:)
        full_width ? "tw:grid tw:grid-cols-[repeat(auto-fit,minmax(4rem,1fr))] tw:gap-2" : "tw:flex tw:flex-wrap tw:gap-2"
      end

      # entries: ComponentStructs::Shapes' entries
      def initialize(entries:, full_width: false)
        @entries = entries
        @full_width = full_width
      end

      def call
        tag.div(class: self.class.layout_classes(full_width: @full_width)) do
          safe_join(@entries.map { |entry| chip(entry) })
        end
      end

      private

      def chip(entry)
        active = entry[:active].presence # false would render data-active="false", nil renders nothing
        # A disabled entry is a <button disabled> even when it has an href — an <a>
        # takes no disabled attribute, so a link would stay live
        href = entry[:disabled] ? nil : entry[:href].presence
        attributes = entry.except(:label, :href, :active).deep_merge(
          class: CHIP_CLASSES,
          data: {active:},
          aria: href ? {current: active} : {pressed: active}
        )
        # The chip is inline-flex, so without the span each of a label's text runs and
        # elements becomes a flex item and the whitespace between them collapses.
        label = tag.span(entry[:label].html_safe)

        href ? link_to(label, href, **attributes) : button_tag(label, type: "button", **attributes)
      end
    end
  end
end
