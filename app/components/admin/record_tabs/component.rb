# frozen_string_literal: true

module Admin
  module RecordTabs
    # The header and tab row for one admin record's screens — the shape every admin record
    # with more than one page uses. A section names its own tabs in a component of its own
    # rather than in each view, so a screen can't disagree with its siblings about what the
    # tabs are; Admin::OrganizationTabs is the pattern.
    class Component < ApplicationComponent
      # What this screen offers besides its tabs, e.g. "New Invoice"
      renders_many :links
      # What's wrong with the record - that it's deleted, that it can't be edited
      renders_one :alert

      # tabs: [{label:, href:, active:}, …]
      def initialize(title:, tabs:, nav_label:, subtitle: nil)
        @title = title
        @tabs = tabs
        @nav_label = nav_label
        @subtitle = subtitle
      end

      private

      attr_reader :tabs

      # .admin-subnav .nav-item a shrinks the padding to .25rem - too tight to read as a tab
      def link_classes(tab)
        ["nav-link tw:px-4! tw:py-2!", ("active" if tab[:active])].compact.join(" ")
      end
    end
  end
end
