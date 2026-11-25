# frozen_string_literal: true

module Pages
  module Org
    module ParkingNotificationDetails
      class Component < ApplicationComponent
        def initialize(parking_notification:, organization:, bike: nil, viewing_impound_record: false, skip_bike: false, display_dev_info: false)
          @parking_notification = parking_notification
          @display_dev_info = display_dev_info
          @organization = organization
          @bike = bike
          @viewing_impound_record = viewing_impound_record
          @skip_bike = skip_bike
        end

        private

        def passed_bike
          @bike || @parking_notification.bike
        end
      end
    end
  end
end
