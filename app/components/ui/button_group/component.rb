# frozen_string_literal: true

module UI
  module ButtonGroup
    # A row of chips that navigate or act — the link/button counterpart of
    # UI::Forms::RadioButtonGroup, which chips off RESTING_CHIP_CLASSES too.
    class Component < ApplicationComponent
      # Mirrors UI::Button color: :secondary, so retuning its grays reaches the chips
      RESTING_CHIP_CLASSES = [
        "tw:cursor-pointer tw:select-none tw:inline-flex tw:items-center tw:justify-center tw:rounded tw:px-3 tw:py-1 tw:text-sm tw:leading-snug tw:transition-colors",
        UI::Button::Component::COLORS[:secondary]
      ].join(" ").freeze

      # The active half is inert until a chip flags itself data-active, the same way
      # UI::Button's is — the radio group restates it off its checked input instead.
      CHIP_CLASSES = [
        RESTING_CHIP_CLASSES,
        "tw:no-underline",
        UI::Button::Component::ACTIVE_COLORS[:secondary],
        UI::Button::Component::FOCUS_CLASSES,
        UI::Button::Component::DISABLED_CLASSES
      ].join(" ").freeze

      # full_width lays the chips out as equal columns that wrap, staying the same width
      # on every line — flex would size each line independently. auto-fit needs a
      # definite minimum to count repetitions.
      def self.layout_classes(full_width:)
        full_width ? "tw:grid tw:grid-cols-[repeat(auto-fit,minmax(4rem,1fr))] tw:gap-2" : "tw:flex tw:flex-wrap tw:gap-2"
      end

      # entries: [{label:, href:, active:, disabled:}, …] — an entry without an href
      # renders a <button>, and anything else in it (data:, title:, target:) becomes
      # an attribute
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
        active = entry[:active] || nil
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
