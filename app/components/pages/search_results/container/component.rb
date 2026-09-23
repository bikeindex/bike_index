# frozen_string_literal: true

module Pages
  module SearchResults
    module Container
      # The marketplace search's results list: the chosen view's <ul>, or the no-results
      # line in its place. Each result renders (and caches) itself, so the results come in
      # as this component's content - built from the component_class this hands back.
      class Component < ApplicationComponent
        # Display order, and the first is what search_result_view falls back to
        RESULT_VIEW_COMPONENT = {
          cards: Pages::SearchResults::BikeCard::Component,
          list: Pages::SearchResults::BikeListItem::Component
        }.freeze

        class << self
          def permitted_result_view(result_view)
            view = result_view&.to_sym

            RESULT_VIEW_COMPONENT.key?(view) ? view : RESULT_VIEW_COMPONENT.keys.first
          end

          def component_class_for_result_view(result_view)
            RESULT_VIEW_COMPONENT[permitted_result_view(result_view)]
          end
        end

        attr_reader :component_class

        def initialize(result_view: nil, no_results: nil)
          @component_class = self.class.component_class_for_result_view(result_view)
          @no_results = no_results || translation(".no_results")
        end

        private

        def container_class = component_class::LIST_CLASSES
      end
    end
  end
end
