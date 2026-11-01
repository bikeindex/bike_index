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
          # Template Dependency: SharedBlocks::Marketing::InvertedBlock::Component

          # What's wrong with the record - that it's deleted, that it can't be edited
          renders_one :alert

          # What the record is - a dark band flush under the tab row, which every tab shares
          renders_one :summary

          # tabs: what UI::Tabs takes; links: what this screen offers besides them, already
          # rendered - e.g. "New Invoice"
          def initialize(title:, tabs:, nav_label:, subtitle: nil, links: [])
            @title = title
            @tabs = tabs
            @nav_label = nav_label
            @subtitle = subtitle
            @links = links
          end

          private

          # The band meets the row, on a heavier line the active tab still breaks through
          def tabs_classes
            return "tw:mb-8" unless summary?

            "tw:mb-0 tw:[&_[data-ui--tabs-target=row]]:border-b-2 tw:[&_[aria-current=page]]:-mb-0.5 " \
              "tw:[&_[aria-current=page]]:border-b-2"
          end
        end
      end
    end
  end
end
