# frozen_string_literal: true

module Org
  module ParkingNotificationDetails
    class Component < ApplicationComponent
      def initialize(parking_notification:, organization:, bike: nil, viewing_impound_record: false, skip_bike: false)
        @parking_notification = parking_notification
        @organization = organization
        @bike = bike
        @viewing_impound_record = viewing_impound_record
        @skip_bike = skip_bike
      end

      private

      def passed_bike
        @bike || @parking_notification.bike
      end

      # A ControllerHelpers method, absent from the Lookbook preview view context
      def display_dev_info?
        helpers.respond_to?(:display_dev_info?) && helpers.display_dev_info?
      end
    end
  end
end
