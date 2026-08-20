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

      # tabs: UI::ButtonGroup entries, [{label:, href:, active:}, …]
      def initialize(title:, tabs:, nav_label:, subtitle: nil)
        @title = title
        @tabs = tabs
        @nav_label = nav_label
        @subtitle = subtitle
      end
    end
  end
end
