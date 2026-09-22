# frozen_string_literal: true

module Pages
  module Org
    module SearchResults
      module BikeListItem
        class ComponentPreview < BikeCard::ComponentPreview
          # Redefined, since only a preview's own methods are listed
          # @param search_all toggle
          def default(search_all: false) = super

          private

          def component_class = Component
        end
      end
    end
  end
end
