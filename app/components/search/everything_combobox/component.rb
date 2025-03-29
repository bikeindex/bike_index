# frozen_string_literal: true

module Search::EverythingCombobox
  class Component < ApplicationComponent
    API_URL = "/api/autocomplete"

    def initialize(selected_query_items_options:, query:)
      @opt_vals = opt_vals_for(selected_query_items_options)
      @query = query
    end

    private

    def opt_vals_for(selected_query_items_options)
      selected_query_items_options.map do |item|
        if item.is_a?(String)
          [item, item]
        else
          [item["text"], item["search_id"]]
        end
      end
    end
  end
end
