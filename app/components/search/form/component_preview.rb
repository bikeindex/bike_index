# frozen_string_literal: true

module Search::Form
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::Form::Component.new(**default_options))
    end

    def chicago_tall_bike
      interpreted_params = BikeSearchable.searchable_interpreted_params({
        stolenness: "proximity", location: "Chicago, IL", query_items: ["v_9"]
      })

      render(Search::Form::Component.new(**default_options(interpreted_params)))
    end

    private

    # this is the path of the raw preview - so when search is submitted, it just re-renders
    def target_search_path
      "/rails/view_components/search/form/component/default"
    end

    def default_options(interpreted_params = nil)
      interpreted_params ||= BikeSearchable.searchable_interpreted_params({})
      {
        target_search_path:,
        interpreted_params:,
        selected_query_items_options: BikeSearchable.selected_query_items_options(interpreted_params)
      }
    end
  end
end
