# frozen_string_literal: true

module Search::VehicleThumbnail
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::VehicleThumbnail::Component.new(vehicle:, current_event_record:, skip_cache:))
    end
  end
end
