# frozen_string_literal: true

module Search::Form
  class ComponentPreview < ApplicationComponentPreview
    def self.default_options(interpreted_params = nil, preview_name: __callee__)
      interpreted_params ||= BikeSearchable.searchable_interpreted_params({})
      {
        # target_search_path is the path of the raw preview - so when search is submitted, it just re-renders
        target_search_path: "/rails/view_components/search/form/component/#{preview_name}",
        target_frame: :search_registrations_results_frame,
        interpreted_params:,
        selected_query_items_options: BikeSearchable.selected_query_items_options(interpreted_params)
      }
    end

    # TODO: It would be nice to group these, but the IDs collide and select2 breaks
    def default
      render(Search::Form::Component.new(**self.class.default_options))
    end

    def chicago_tall_bike
      interpreted_params = BikeSearchable.searchable_interpreted_params({
        stolenness: "proximity", location: "Chicago, IL", query_items: ["v_9"]
      })

      render(Search::Form::Component.new(**self.class.default_options(interpreted_params)))
    end

    def for_sale
      sale_options = self.class.default_options({stolenness: :all})
        .merge(target_frame: :search_marketplace_results_frame, marketplace_scope: "for_sale")
      render(Search::Form::Component.new(**sale_options))
    end

    def for_sale_san_francisco_atb
      sale_options = self.class.default_options(BikeSearchable.searchable_interpreted_params({
        stolenness: :all, location: "San Francisco, CA", distance: 101, primary_activity: "ATB"
      })).merge(target_frame: :search_marketplace_results_frame, marketplace_scope: "for_sale_proximity")

      render(Search::Form::Component.new(**sale_options))
      # sale_options = default_options({stolenness: :all}, preview_name: "for_sale").merge(
      #   target_frame: :search_marketplace_results_frame,
      #   marketplace_scope: "for_sale"
      # )
      # render Search::Form::Component.new(preview_name: "for_sale_san_francisco_atb",  interpreted_params:,
      #   target_frame: :search_marketplace_results_frame, marketplace_scope: "for_sale", selected_query_items_options: [])
    end

    private

    # def default_options(interpreted_params = nil, preview_name: __callee__)
    #   interpreted_params ||= BikeSearchable.searchable_interpreted_params({})
    #   {
    #     # target_search_path is the path of the raw preview - so when search is submitted, it just re-renders
    #     target_search_path: "/rails/view_components/search/form/component/#{preview_name}",
    #     target_frame: :search_registrations_results_frame,
    #     interpreted_params:,
    #     selected_query_items_options: BikeSearchable.selected_query_items_options(interpreted_params)
    #   }
    # end
  end
end
