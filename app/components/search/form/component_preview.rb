# frozen_string_literal: true

module Search::Form
  class ComponentPreview < ApplicationComponentPreview
    # TODO: It would be nice to group these, but the IDs collide and select2 breaks
    def default
      render(Search::Form::Component.new(**default_options(preview_name: "default")))
    end

    def chicago_tall_bike
      interpreted_params = BikeSearchable.searchable_interpreted_params({
        stolenness: "proximity", location: "Chicago, IL", query_items: ["v_9"]
      })

      render(Search::Form::Component.new(**default_options(interpreted_params, preview_name: "chicago_tall_bike")))
    end

    def for_sale
      sale_options = default_options({stolenness: :all}, preview_name: "for_sale").merge(
        target_frame: :search_marketplace_results_frame,
        marketplace_scope: "for_sale"
      )
      render(Search::Form::Component.new(**sale_options))
    end

    def for_sale_san_francisco_atb
      sale_options = default_options(BikeSearchable.searchable_interpreted_params({
        stolenness: :all, location: "San Francisco, CA", distance: 101, primary_activity: "ATB"
      }), preview_name: "for_sale_san_francisco_atb")
        .merge(target_frame: :search_marketplace_results_frame, marketplace_scope: "for_sale_proximity")

      render(Search::Form::Component.new(**sale_options))
    end

    private

    # this is the path of the raw preview - so when search is submitted, it just re-renders
    def target_search_path(preview_name)
      "/rails/view_components/search/form/component/#{preview_name}"
    end

    def default_options(interpreted_params = nil, preview_name:)
      interpreted_params ||= BikeSearchable.searchable_interpreted_params({})
      {
        target_search_path: target_search_path(preview_name),
        target_frame: :search_registrations_results_frame,
        interpreted_params:
      }
    end
  end
end
