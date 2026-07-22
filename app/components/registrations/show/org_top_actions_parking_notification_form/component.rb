# frozen_string_literal: true

module Registrations
  module Show
    module OrgTopActionsParkingNotificationForm
      # Org-admin parking-notification / impound form panel. Rendered inside the
      # org-admin action-panel accordion (data-panel-name="parking"); the Stimulus
      # `registrations--show--parking-notification` controller wires up geolocation
      # and the impound/notification mode switch
      class Component < ApplicationComponent
        def initialize(bike:, organization:)
          @bike = bike
          @organization = organization
        end

        private

        def new_parking_notification
          return @new_parking_notification if defined?(@new_parking_notification)

          notification = ::ParkingNotification.new(bike_id: @bike.id, organization: @organization, use_entered_address: false)
          notification.is_repeat = notification.likely_repeat?
          notification.set_location_from_organization
          notification.kind ||= notification.potential_initial_record&.kind || ::ParkingNotification.kinds.first
          @new_parking_notification = notification
        end

        def create_parking_notifications_path
          organization_parking_notifications_path(organization_id: @organization.to_param)
        end
      end
    end
  end
end
