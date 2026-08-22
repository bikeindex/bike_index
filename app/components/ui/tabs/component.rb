# frozen_string_literal: true

module UI
  module Tabs
    # A row of tabs with its own underline, which the active tab breaks through. A row too
    # wide for the screen scrolls sideways rather than wrapping.
    #
    # tabs: ComponentStructs::Shapes' tabs
    class Component < ApplicationComponent
      TAB_CLASSES = "tw:-mb-px tw:inline-flex tw:items-baseline tw:gap-1 tw:whitespace-nowrap " \
        "tw:rounded-t-md tw:border tw:px-4 tw:py-2 tw:text-sm tw:no-underline"
      # The white lower edge is what breaks the row's border, so the tab reads as a tab. The
      # border color belongs to each state rather than to TAB_CLASSES - tailwind orders its
      # own utilities, so a base border-transparent would beat this whatever the attribute says
      ACTIVE_CLASSES = "tw:border-gray-300 tw:border-b-white tw:bg-white tw:font-semibold tw:text-gray-900"
      INACTIVE_CLASSES = "twlink tw:border-transparent tw:hover:bg-gray-100"

      # turbo: Drive is off app-wide and opted into per element; one data-turbo on the nav
      # covers every tab, since Turbo reads it off the closest ancestor carrying it
      def initialize(tabs:, nav_label:, turbo: false)
        @tabs = tabs
        @nav_label = nav_label
        @turbo = turbo
      end

      private

      def link_classes(tab)
        [TAB_CLASSES, tab[:active] ? ACTIVE_CLASSES : INACTIVE_CLASSES, tab[:classes]].compact.join(" ")
      end
    end
  end
end
