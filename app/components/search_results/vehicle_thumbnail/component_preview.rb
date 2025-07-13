# frozen_string_literal: true

module SearchResults::VehicleThumbnail
  class ComponentPreview < ApplicationComponentPreview
    def default
      {template: "search_results/vehicle_thumbnail/component_preview/default"}
    end
  end
end
