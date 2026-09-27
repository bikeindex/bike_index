# frozen_string_literal: true

module SharedBlocks
  module SearchResults
    module Container
      # The marketplace search's results: the chosen view's <ul> of them, or the no-results
      # line in its place. Each result caches itself, so nothing here wraps them in a cache.
      class Component < ApplicationComponent
        # Display order, and the first is what search_result_view falls back to
        RESULT_VIEW_COMPONENT = {
          cards: SharedBlocks::SearchResults::BikeCard::Component,
          list: SharedBlocks::SearchResults::BikeListItem::Component
        }.freeze

        # Cards cap at 4 columns, so a page of 12 - each lazily loaded page is its own
        # grid - fills its rows at every width
        LIST_CLASSES = {
          cards: "tw:grid tw:grid-cols-[repeat(auto-fill,minmax(max(14rem,calc((100%_-_3rem)/4)),1fr))] tw:gap-4",
          list: SharedBlocks::SearchResults::BikeListItem::Component::LIST_CLASSES
        }.freeze

        def self.permitted_result_view(result_view)
          view = result_view&.to_sym

          RESULT_VIEW_COMPONENT.key?(view) ? view : RESULT_VIEW_COMPONENT.keys.first
        end

        def initialize(bikes:, no_results:, result_view: nil)
          @result_view = self.class.permitted_result_view(result_view)
          @component_class = RESULT_VIEW_COMPONENT[@result_view]
          @bikes = bikes
          @no_results = no_results
        end
      end
    end
  end
end
