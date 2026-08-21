# frozen_string_literal: true

module UI
  module Tabs
    # A row of tabs with its own underline, which the active tab breaks through. It scrolls
    # sideways rather than wrapping, and below md each tab is its first letter alone - the
    # shape the admin bike tabs established, so a row too wide for a phone stays one row.
    #
    # tabs: [{label:, href:, active:, count:}, …] - count is optional, and stays visible
    # when the label truncates
    class Component < ApplicationComponent
      TAB_CLASSES = "tw:-mb-px tw:inline-flex tw:items-baseline tw:gap-1 tw:whitespace-nowrap " \
        "tw:rounded-t-md tw:border tw:px-4 tw:py-2 tw:text-sm tw:no-underline"
      # The white lower edge is what breaks the row's border, so the tab reads as a tab. The
      # border color belongs to each state rather than to TAB_CLASSES - tailwind orders its
      # own utilities, so a base border-transparent would beat this whatever the attribute says
      ACTIVE_CLASSES = "tw:border-gray-300 tw:border-b-white tw:bg-white tw:font-semibold tw:text-gray-900"
      INACTIVE_CLASSES = "twlink tw:border-transparent tw:hover:bg-gray-100"

      def initialize(tabs:, nav_label:)
        @tabs = tabs
        @nav_label = nav_label
      end

      private

      def link_classes(tab)
        [TAB_CLASSES, tab[:active] ? ACTIVE_CLASSES : INACTIVE_CLASSES].join(" ")
      end

      # Narrow screens get the first letter alone - sr-only rather than hidden, so the tab is
      # still announced by its whole name. One span, so the link's own gap separates the
      # label from its count rather than splitting the first letter off the rest
      def tab_label(tab)
        label = tab[:label].to_s

        tag.span(safe_join([label.first, tag.span(label[1..], class: "tw:sr-only tw:md:not-sr-only")]))
      end
    end
  end
end
