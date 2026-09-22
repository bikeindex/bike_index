# frozen_string_literal: true

module Pages
  module Org
    module Search
      module SettingsAndFilters
        # The row under the search fields - the gear, the date range, and what the search is
        # filtered to - and the settings panel the gear opens. Every label comes from
        # ComponentStructs::OrgSearchSettings, which the table reads its column names out of too.
        #
        # It renders beside the search form rather than inside it: the custom date range is a
        # form of its own, which can't nest. The radios reach the search with form:.
        class Component < ApplicationComponent
          delegate :filter_groups, :active_search_filter_descriptions, :notes_search_label,
            :organization, to: :@settings

          def initialize(settings:, period:, start_time:, end_time:, sortable_search_params: {})
            @settings = settings
            @period = period
            @start_time = start_time
            @end_time = end_time
            @sortable_search_params = sortable_search_params
          end

          def notes_search?
            organization.enabled?("registration_notes")
          end

          private

          def period_label
            UI::PeriodSelect::Component.period_label(@period)
          end

          def group_chips(group)
            UI::Forms::RadioButtonGroup::Component.new(
              name: group[:name],
              selected: group[:selected],
              entries: group[:entries],
              form: "Search_Form",
              data: {action: "change->org--search#filterChanged"}
            )
          end
        end
      end
    end
  end
end
