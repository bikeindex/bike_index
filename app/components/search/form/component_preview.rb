# frozen_string_literal: true

module Search::Form
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::Form::Component.new(**default_options))
    end

    private

    def default_options(interpreted_params = nil)
      interpreted_params ||= BikeSearchable.searchable_interpreted_params({})
      {
        target_search_path: search_index_path,
        interpreted_params:,
        selected_query_items_options: BikeSearchable.selected_query_items_options(interpreted_params)
      }
    end
  end
end
