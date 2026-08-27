# frozen_string_literal: true

module UI
  module Tabs
    # A row of tabs with its own underline, which the active tab breaks through. A row too
    # wide for the screen scrolls sideways rather than wrapping.
    #
    # tabs: ComponentStructs::Shapes' tabs
    class Component < ApplicationComponent
      # tw:is-active: keys off the aria-current the template sets, and sorts after everything
      # it overrides. The white lower edge is what breaks the row's border, so the tab reads
      # as a tab
      TAB_CLASSES = "twlink tw:-mb-px tw:inline-flex tw:items-baseline tw:gap-1 tw:whitespace-nowrap " \
        "tw:rounded-t-md tw:border tw:border-transparent tw:px-4 tw:py-2 tw:text-sm tw:no-underline " \
        "tw:hover:bg-gray-100 tw:is-active:border-gray-300 tw:is-active:border-b-white " \
        "tw:is-active:bg-white tw:is-active:font-semibold tw:is-active:text-gray-900"

      # turbo: Drive is off app-wide and opted into per element; one data-turbo on the nav
      # covers every tab, since Turbo reads it off the closest ancestor carrying it
      def initialize(tabs:, nav_label:, turbo: false)
        @tabs = tabs
        @nav_label = nav_label
        @turbo = turbo
      end

      private

      def link_classes(tab) = [TAB_CLASSES, tab[:classes]].compact.join(" ")
    end
  end
end
