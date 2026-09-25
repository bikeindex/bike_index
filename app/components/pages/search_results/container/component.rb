# frozen_string_literal: true

module Pages
  module SearchResults
    module Container
      # The marketplace search's results: the chosen view's <ul> of them, or the no-results
      # line in its place. Each result caches itself, so nothing here wraps them in a cache.
      class Component < ApplicationComponent
        # Display order, and the first is what search_result_view falls back to
        RESULT_VIEW_COMPONENT = {
          cards: Pages::SearchResults::BikeCard::Component,
          list: Pages::SearchResults::BikeListItem::Component
        }.freeze

        def self.permitted_result_view(result_view)
          view = result_view&.to_sym

          RESULT_VIEW_COMPONENT.key?(view) ? view : RESULT_VIEW_COMPONENT.keys.first
        end

        def initialize(bikes:, no_results:, result_view: nil)
          @component_class = RESULT_VIEW_COMPONENT[self.class.permitted_result_view(result_view)]
          @bikes = bikes
          @no_results = no_results
        end
      end
    end
  end
end
