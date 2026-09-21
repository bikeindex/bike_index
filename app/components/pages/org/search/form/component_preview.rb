# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Form
        class ComponentPreview < ApplicationComponentPreview
          # @!group Variants
          # The registrations search, which brings the filters. First, since the group shares a
          # page and form: "Search_Form" finds the first form on it
          def with_filters
            render(Pages::Org::Search::Form::Component.new(**default_options.merge(filters_component:)))
          end

          # The impound records, graduated notifications and parking notifications searches
          def default
            render(Pages::Org::Search::Form::Component.new(**default_options))
          end

          def with_serial_value
            interpreted_params = {raw_serial: "ABC123", serial: "ABC123", query: nil}
            render(Pages::Org::Search::Form::Component.new(**default_options(interpreted_params)))
          end
          # @!endgroup

          private

          def filters_component
            Pages::Org::Search::SettingsAndFilters::Component.new(
              settings: ComponentStructs::OrgSearchSettings.new(organization: lookbook_organization),
              period: "week", start_time: Time.current - 1.week, end_time: Time.current
            )
          end

          def target_search_path
            "/rails/view_components/pages/org/search/form/component/default"
          end

          def default_options(interpreted_params = {})
            {
              target_search_path:,
              interpreted_params:,
              heading: "Find a registration",
              submit_text: "Search registrations"
            }
          end
        end
      end
    end
  end
end
