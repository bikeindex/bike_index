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
            registrations_search(search_all: false)
          end

          # The impound records, graduated notifications and parking notifications searches
          def default
            render(Pages::Org::Search::Form::Component.new(**default_options))
          end

          def searching_all_registrations
            registrations_search(search_all: true, interpreted_params: {raw_serial: "ABC123", serial: "ABC123", query: nil})
          end
          # @!endgroup

          private

          def registrations_search(search_all:, interpreted_params: {})
            settings = ComponentStructs::OrgSearchSettings.new(organization: lookbook_organization, search_all:)
            settings_and_filters_component = Pages::Org::Search::SettingsAndFilters::Component.new(
              settings:, period: "week", start_time: Time.current - 1.week, end_time: Time.current
            )

            {template: "pages/org/search/form/component_preview/registrations_search",
             locals: {settings:,
                      options: default_options(interpreted_params).merge(settings_and_filters_component:)}}
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
