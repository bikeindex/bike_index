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

        def edit_theft_details_path(bike)
          edit_bike_path(bike.to_param, edit_template: "theft_details", anchor: "where-theft-happened")
        end
      end
    end
  end
end
