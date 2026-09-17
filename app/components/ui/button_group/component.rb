# frozen_string_literal: true

module UI
  module ButtonGroup
    # A row of chips that navigate or act — the link/button counterpart of
    # UI::Forms::RadioButtonGroup, which chips off CHIP_CLASSES too.
    #
    # style: :button is a row of separate chips; :toggle is the redesign's segmented
    # control, where the group is one track and the active entry is the raised segment in it.
    class Component < ApplicationComponent
      STYLES = %i[button toggle].freeze

      CHIP_CLASSES = UI::Button::Component.build_classes(color: :secondary, size: :md).freeze

      TRACK_CLASSES = "tw:inline-flex tw:gap-0.5 tw:rounded-lg tw:border tw:border-gray-200 " \
        "tw:bg-gray-100 tw:p-0.5 tw:dark:border-gray-700 tw:dark:bg-gray-800"

      # Only the segment's own look: the focus, disabled and hover-guard halves come from
      # UI::Button, whose rationales for each shouldn't need a second copy here.
      # Resting is the unselected segment; is-active raises the selected one out of the track.
      SEGMENT_CLASSES = [
        "tw:inline-flex tw:items-center tw:cursor-pointer tw:transition-colors tw:rounded-md",
        "tw:px-3 tw:py-1 tw:text-2xs tw:font-extrabold tw:whitespace-nowrap",
        "tw:no-underline tw:hover:no-underline tw:text-gray-400",
        "tw:not-disabled:not-aria-disabled:hover:text-gray-900",
        "tw:focus:ring-purple-500/40",
        UI::Button::Component::FOCUS_CLASSES,
        UI::Button::Component::DISABLED_CLASSES,
        "tw:is-active:bg-white tw:is-active:text-gray-900 tw:is-active:shadow-sm",
        "tw:dark:is-active:bg-gray-900 tw:dark:is-active:text-gray-100"
      ].join(" ").freeze

      # full_width lays the chips out as equal columns that wrap, staying the same width
      # on every line — flex would size each line independently. auto-fit needs a
      # definite minimum to count repetitions.
      def self.layout_classes(full_width:)
        return "tw:grid tw:grid-cols-[repeat(auto-fit,minmax(4rem,1fr))] tw:gap-2" if full_width

        "tw:flex tw:flex-wrap tw:gap-2"
      end

      # entries: ComponentStructs::Shapes' entries
      def initialize(entries:, full_width: false, style: :button)
        raise ArgumentError, "unknown style #{style.inspect}, expected one of: #{STYLES.join(", ")}" unless STYLES.include?(style)

        @entries = entries
        @full_width = full_width
        @style = style
      end

      def call
        tag.div(class: group_classes) do
          safe_join(@entries.map { |entry| chip(entry) })
        end
      end

      private

      def toggle?
        @style == :toggle
      end

      def group_classes
        toggle? ? TRACK_CLASSES : self.class.layout_classes(full_width: @full_width)
      end

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
