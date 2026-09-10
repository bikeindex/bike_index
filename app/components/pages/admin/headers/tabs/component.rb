# frozen_string_literal: true

module Pages
  module Admin
    module Headers
      module Tabs
        # The header and tab row for one admin record's screens — the shape every admin record
        # with more than one page uses. A section names its own tabs in a component of its own
        # rather than in each view, so a screen can't disagree with its siblings about what the
        # tabs are; Pages::Admin::Organizations::Tabs is the pattern.
        class Component < ApplicationComponent
          # What's wrong with the record - that it's deleted, that it can't be edited
          renders_one :alert

          # tabs: what UI::Tabs takes; links: what this screen offers besides them, already
          # rendered - e.g. "New Invoice"
          #
          # turbo: Drive is off app-wide, so a section opts in only when every screen it links
          # to survives a snapshot restore - not the ones carrying legacy admin bundle JS,
          # which a Drive visit never re-runs
          def initialize(title:, tabs:, nav_label:, subtitle: nil, links: [], turbo: false)
            @title = title
            @tabs = tabs
            @nav_label = nav_label
            @subtitle = subtitle
            @links = links
            @turbo = turbo
          end
        end
      end
    end
  end
end
