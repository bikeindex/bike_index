# frozen_string_literal: true

module SharedBlocks
  module UserAlerts
    module StolenBikeWithoutLocation
      class Component < ApplicationComponent
        MODAL_ID = "stolen-missing-location"

        def initialize(bikes:)
          @bikes = bikes
        end

        def render?
          @bikes.present?
        end

        private

        def bike_type
          @bikes.first.type
        end

        def theft_location_path(bike)
          edit_bike_stolen_report_path(bike.to_param, step: "where")
        end
      end
    end
  end
end
