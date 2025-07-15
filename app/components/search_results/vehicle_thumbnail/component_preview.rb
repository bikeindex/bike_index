# frozen_string_literal: true

module SearchResults::VehicleThumbnail
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(SearchResults::Container::Component.new(
        li_kind: :thumbnail,
        search_kind: :marketplace,
        vehicles: SearchResults::BikeBox::ComponentPreview.vehicles + SearchResults::BikeBox::ComponentPreview.vehicles
      ))
    end
  end
end
