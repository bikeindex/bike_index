# frozen_string_literal: true

module SearchOrg
  module Form
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(SearchOrg::Form::Component.new(**default_options))
      end

      def with_serial_value
        interpreted_params = {raw_serial: "ABC123", serial: "ABC123", query: nil}
        render(SearchOrg::Form::Component.new(**default_options(interpreted_params)))
      end

      def without_serial_field
        render(SearchOrg::Form::Component.new(**default_options.merge(skip_serial_field: true)))
      end

      private

      def target_search_path
        "/rails/view_components/search_org/form/component/default"
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
