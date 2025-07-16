# frozen_string_literal: true

module SearchResults::VehicleThumbnail
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(SearchResults::Container::Component.new(
        li_kind: :thumbnail,
        search_kind: :registration,
        vehicles: SearchResults::BikeBox::ComponentPreview.vehicles + SearchResults::BikeBox::ComponentPreview.vehicles
      ))
    end

    def marketplace
      render(SearchResults::Container::Component.new(
        li_kind: :thumbnail,
        search_kind: :marketplace,
        vehicles: marketplace_vehicles
      ))
    end

    private

    def marketplace_vehicles
      Bike.for_sale.limit(15)
    end
  end
end
