# frozen_string_literal: true

module Search::FormOrganized
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::FormOrganized::Component.new(**default_options))
    end

    def with_serial_value
      interpreted_params = {raw_serial: "ABC123", serial: "ABC123", query: nil}
      render(Search::FormOrganized::Component.new(**default_options(interpreted_params)))
    end

    def without_serial_field
      render(Search::FormOrganized::Component.new(**default_options.merge(skip_serial_field: true)))
    end

    private

    def target_search_path
      "/rails/view_components/search/form_organized/component/default"
    end

    def default_options(interpreted_params = {})
      {
        target_search_path:,
        target_frame: :search_organized_results_frame,
        interpreted_params:
      }
    end
  end
end
