# frozen_string_literal: true

module Search::EverythingCombobox
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::EverythingCombobox::Component.new(selected_query_items_options:, query:))
    end
  end
end
