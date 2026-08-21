# frozen_string_literal: true

module Admin
  module RecordTabs
    # The header and tab row for one admin record's screens — the shape every admin record
    # with more than one page uses. A section names its own tabs in a component of its own
    # rather than in each view, so a screen can't disagree with its siblings about what the
    # tabs are; Admin::Organizations::Tabs is the pattern.
    class Component < ApplicationComponent
      # What's wrong with the record - that it's deleted, that it can't be edited
      renders_one :alert

      # tabs: what UI::Tabs takes; links: what this screen offers besides them, already
      # rendered - e.g. "New Invoice"
      def initialize(title:, tabs:, nav_label:, subtitle: nil, links: [])
        @title = title
        @tabs = tabs
        @nav_label = nav_label
        @subtitle = subtitle
        @links = links
      end
    end
  end
end
