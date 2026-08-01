# frozen_string_literal: true

module PageBlock
  module UserAlerts
    module StolenBikeWithoutLocation
      # Opens on page load, linking each stolen registration missing a street to the
      # theft details form
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
