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

          private

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
