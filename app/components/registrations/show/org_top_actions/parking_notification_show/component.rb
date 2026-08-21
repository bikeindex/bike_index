# frozen_string_literal: true

module Registrations
  module Show
    module OrgTopActions
      module ParkingNotificationShow
        # Accordion panel opened from the org-admin "View notifications" action — a
        # summary of the bike's current parking notification, with a link to all
        class Component < ApplicationComponent
          def initialize(bike:, organization:, display_dev_info: false)
            @bike = bike
            @organization = organization
            @display_dev_info = display_dev_info
          end

          private

          # The current notification, falling back to the most recent one
          def parking_notification
            return @parking_notification if defined?(@parking_notification)

            notifications = @organization.parking_notifications.where(bike_id: @bike.id).reorder(id: :desc)
            @parking_notification = notifications.detect(&:current?) || notifications.first
          end

          def notification_path
            organization_parking_notification_path(parking_notification.id, organization_id: @organization.to_param)
          end

          def notifications_path
            organization_parking_notifications_path(organization_id: @organization.to_param, search_bike_id: @bike.id, search_status: "all")
          end
        end
      end
    end
  end
end
