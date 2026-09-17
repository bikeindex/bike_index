# frozen_string_literal: true

module UI
  module ButtonGroup
    # A row of chips that navigate or act — the link/button counterpart of
    # UI::Forms::RadioButtonGroup, which chips off CHIP_CLASSES too.
    #
    # kind: :toggle renders them as a segmented control instead — one track, with the
    # active entry raised out of it.
    class Component < ApplicationComponent
      KINDS = %i[button toggle].freeze

      CHIP_CLASSES = UI::Button::Component.build_classes(color: :secondary, size: :md).freeze

      # Track and segment sizes come from kelsey_redesign/new-org-search/, not the type scale
      TRACK_CLASSES = "tw:inline-flex tw:gap-[3px] tw:rounded-[10px] tw:border tw:border-gray-200 " \
        "tw:bg-gray-100 tw:p-[3px] tw:dark:border-gray-700 tw:dark:bg-gray-800"

      # Only what the segment doesn't share with a button — the rest is UI::Button's
      SEGMENT_CLASSES = [
        UI::Button::Component::BASE_CLASSES,
        UI::Button::Component::FOCUS_CLASSES,
        UI::Button::Component::DISABLED_CLASSES,
        "tw:px-3 tw:py-[5px] tw:text-[11.5px] tw:font-extrabold tw:whitespace-nowrap",
        "tw:no-underline tw:hover:no-underline tw:text-gray-400",
        "tw:not-disabled:not-aria-disabled:hover:text-gray-900",
        "tw:focus:ring-purple-500/40",
        "tw:is-active:bg-white tw:is-active:text-gray-900 tw:is-active:shadow-sm",
        "tw:is-active:dark:bg-gray-900 tw:is-active:dark:text-gray-100"
      ].join(" ").freeze

      # full_width lays the chips out as equal columns that wrap, staying the same width
      # on every line — flex would size each line independently. auto-fit needs a
      # definite minimum to count repetitions.
      def self.layout_classes(full_width:)
        full_width ? "tw:grid tw:grid-cols-[repeat(auto-fit,minmax(4rem,1fr))] tw:gap-2" : "tw:flex tw:flex-wrap tw:gap-2"
      end

      # entries: ComponentStructs::Shapes' entries
      def initialize(entries:, full_width: false, kind: :button)
        raise ArgumentError, "unknown kind #{kind.inspect}, expected one of: #{KINDS.join(", ")}" unless KINDS.include?(kind)
        # The track sizes itself to its segments, so there's no column layout to widen
        raise ArgumentError, "full_width is not supported for the toggle kind" if full_width && kind == :toggle

        @entries = entries
        @full_width = full_width
        @kind = kind
      end

      def call
        tag.div(class: group_classes) do
          safe_join(@entries.map { |entry| chip(entry) })
        end
      end

      private

      def toggle? = @kind == :toggle

      def group_classes = toggle? ? TRACK_CLASSES : self.class.layout_classes(full_width: @full_width)

      def chip(entry)
        active = entry[:active].presence # false would render data-active="false", nil renders nothing
        # A disabled entry is a <button disabled> even when it has an href — an <a>
        # takes no disabled attribute, so a link would stay live
        href = entry[:disabled] ? nil : entry[:href].presence
        attributes = entry.except(:label, :href, :active).deep_merge(
          class: toggle? ? SEGMENT_CLASSES : CHIP_CLASSES,
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
