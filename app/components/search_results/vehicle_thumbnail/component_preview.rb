# frozen_string_literal: true

module SearchResults::VehicleThumbnail
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(SearchResults::VehicleThumbnail::Component.new(vehicle:, current_event_record:, skip_cache:))
    end
  end
end
