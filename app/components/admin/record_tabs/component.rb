# frozen_string_literal: true

module Admin
  module RecordTabs
    # The header and tab row for one admin record's screens — the shape every admin record
    # with more than one page uses. A section names its own tabs in a component of its own
    # rather than in each view, so a screen can't disagree with its siblings about what the
    # tabs are; Admin::OrganizationTabs is the pattern.
    class Component < ApplicationComponent
      TAB_CLASSES = "tw:inline-flex tw:items-baseline tw:gap-1 tw:whitespace-nowrap " \
        "tw:rounded-t-md tw:border tw:px-4 tw:py-2 tw:text-sm tw:no-underline"
      # The white lower edge is what breaks .admin-subnav's border, so the tab reads as a tab.
      # The border color belongs to each state rather than to TAB_CLASSES - tailwind orders
      # its own utilities, so a base border-transparent would beat this whatever the attribute says
      ACTIVE_CLASSES = "tw:border-gray-300 tw:border-b-white tw:bg-white tw:font-semibold tw:text-gray-900"
      INACTIVE_CLASSES = "twlink tw:border-transparent tw:hover:bg-gray-100"

      # What's wrong with the record - that it's deleted, that it can't be edited
      renders_one :alert

      # tabs: [{label:, href:, active:, count:}, …]; links: what this screen offers besides
      # them, already rendered - e.g. "New Invoice"
      def initialize(title:, tabs:, nav_label:, subtitle: nil, links: [])
        @title = title
        @tabs = tabs
        @nav_label = nav_label
        @subtitle = subtitle
        @links = links
      end

      private

      def link_classes(tab)
        [TAB_CLASSES, tab[:active] ? ACTIVE_CLASSES : INACTIVE_CLASSES].join(" ")
      end

      # Narrow screens get the first letter alone - sr-only rather than hidden, so the tab
      # is still announced by its whole name. safe_join with no separator: a space between
      # the two would show up mid-word once the rest is visible
      def tab_label(tab)
        label = tab[:label].to_s

        # One span, so the link's own gap separates the label from its count rather than
        # splitting the first letter off the rest
        tag.span(safe_join([label.first, tag.span(label[1..], class: "tw:sr-only tw:md:not-sr-only")]))
      end
    end
  end
end
