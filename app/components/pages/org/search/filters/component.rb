# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Filters
        # The quick-filter chip row under the search fields, and the settings panel the gear
        # opens. Every label comes from Pages::Org::Search::Settings, which the table reads
        # its column names out of too.
        #
        # It renders beside the search form rather than inside it: the custom date range is a
        # form of its own, which can't nest. The radios reach the search with form:.
        class Component < ApplicationComponent
          FORM_ID = "Search_Form"

          delegate :filter_groups, :quick_filter_entries, :notes_search_label, to: :@settings_component

          def initialize(settings_component:, period:, start_time:, end_time:,
            sortable_search_params: {}, notes_search: false)
            @settings_component = settings_component
            @period = period
            @start_time = start_time
            @end_time = end_time
            @sortable_search_params = sortable_search_params
            @notes_search = notes_search
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
              form: FORM_ID,
              data: {action: "change->org--search#filterChanged"}
            )
          end
        end
      end
    end
  end
end
