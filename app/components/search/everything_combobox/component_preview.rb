# frozen_string_literal: true

module Search::EverythingCombobox
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::EverythingCombobox::Component.new(**default_options))
    end

    private

    def default_options(interpreted_params = nil)
      interpreted_params ||= BikeSearchable.searchable_interpreted_params({})
      {
        query: interpreted_params[:query],
        selected_query_items_options: BikeSearchable.selected_query_items_options(interpreted_params)
      }
    end
  end
end
