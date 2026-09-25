# frozen_string_literal: true

module Pages
  module Org
    module SearchResults
      module BikeListItem
        # One registration in the org search's list view, per the Bike Thumbnails design doc's
        # dense row (1d): BikeCard's contents, edged in the status's color
        class Component < BikeCard::Component
          # The rows wrap against their list, so they fit a narrow card too
          LIST_CLASSES = "tw:@container tw:flex tw:flex-col tw:gap-3"

          BORDER_CLASSES = {
            success: "tw:border-l-green-600",
            purple: "tw:border-l-purple-500",
            error: "tw:border-l-red-600",
            warning: "tw:border-l-amber-500",
            pink: "tw:border-l-pink-400"
          }.freeze

          private

          # BikeCard's, whose methods this shares - config/i18n-tasks.yml's scope_overrides too
          def component_translation_scope = %i[components pages org search_results bike_card]

          def row_border_class
            BORDER_CLASSES.fetch(Atoms::RegistrationStatusBadge::Component.color(@bike), "tw:border-l-gray-300")
          end
        end
      end
    end
  end
end
