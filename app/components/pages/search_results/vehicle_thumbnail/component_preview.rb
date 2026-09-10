# frozen_string_literal: true

module Pages
  module SearchResults
    module VehicleThumbnail
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::SearchResults::Container::Component.new(
            result_view: :thumbnail,
            search_kind: :registration,
            vehicles: Pages::SearchResults::BikeBox::ComponentPreview.vehicles + Pages::SearchResults::BikeBox::ComponentPreview.vehicles
          ))
        end

        def marketplace
          render(Pages::SearchResults::Container::Component.new(
            result_view: :thumbnail,
            search_kind: :marketplace,
            vehicles: marketplace_vehicles
          ))
        end

        def no_results
          render(Pages::SearchResults::Container::Component.new(
            result_view: :thumbnail,
            search_kind: :marketplace,
            vehicles: nil
          ))
        end

        private

        def marketplace_vehicles
          Bike.for_sale.limit(15)
        end
      end
    end
  end
end
