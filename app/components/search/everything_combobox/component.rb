# frozen_string_literal: true

module Search::EverythingCombobox
  class Component < ApplicationComponent
    def initialize(selected_query_items_options:, query:)
      @selected_query_items_options = selected_query_items_options
    @query = query
    end
  end
end
