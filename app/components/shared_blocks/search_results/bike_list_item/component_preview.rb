# frozen_string_literal: true

module SharedBlocks
  module SearchResults
    module BikeListItem
      class ComponentPreview < SharedBlocks::SearchResults::BikeCard::ComponentPreview
        # @!group Variants
        # Redefined, since only a preview's own methods are listed
        # @param search_all toggle
        # @param organized toggle "An org search, linking each row to its org page - off is the marketplace's"
        def default(search_all: false, organized: true) = super

        # How long a bike has been registered is what vouches for it, so a bike with its
        # owner is badged only here. Every other status renders either way.
        # @param search_all toggle
        def with_credibility_badges(search_all: false) = super
        # @!endgroup

        private

        def component_class = Component
      end
    end
  end
end
