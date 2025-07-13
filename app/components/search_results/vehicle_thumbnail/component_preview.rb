# frozen_string_literal: true

module SearchResults::VehicleThumbnail
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(SearchResults::Container::Component.new(
        component_class: SearchResults::VehicleThumbnail::Component,
        vehicles: SearchResults::BikeBox::ComponentPreview.vehicles
      ))
    end
  end
end
