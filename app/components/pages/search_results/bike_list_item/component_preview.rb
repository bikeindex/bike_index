# frozen_string_literal: true

module Pages
  module SearchResults
    module BikeListItem
      class ComponentPreview < BikeCard::ComponentPreview
        # Redefined, since only a preview's own methods are listed
        # @param search_all toggle
        # @param organized toggle "An org search, linking each row to its org page - off is the marketplace's"
        def default(search_all: false, organized: true) = super

        private

        def component_class = Component
      end
    end
  end
end
