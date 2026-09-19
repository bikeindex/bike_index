# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Form
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(Pages::Org::Search::Form::Component.new(**default_options))
          end

          def with_serial_value
            interpreted_params = {raw_serial: "ABC123", serial: "ABC123", query: nil}
            render(Pages::Org::Search::Form::Component.new(**default_options(interpreted_params)))
          end

          def without_serial_field
            render(Pages::Org::Search::Form::Component.new(**default_options.merge(skip_serial_field: true)))
          end

          # The registrations search: a card, with the filters and a full-width submit
          def card
            render(Pages::Org::Search::Form::Component.new(**default_options.merge(
              heading: "Find a bike", submit_text: "Search registrations",
              filters_component:
            )))
          end

          private

          def filters_component
            Pages::Org::Search::Filters::Component.new(
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
              interpreted_params:
            }
          end
        end
      end
    end
  end
end
