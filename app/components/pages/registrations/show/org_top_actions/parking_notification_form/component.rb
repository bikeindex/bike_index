# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module OrgTopActions
        module ParkingNotificationForm
          # Org-admin parking-notification / impound form panel. Rendered inside the
          # org-admin action-panel accordion (data-panel-name="parking"); the Stimulus
          # `registrations--show--parking-notification-form` controller wires up the map
          # pin, geolocation, the address fields and the impound/notification switch
          class Component < ApplicationComponent
            def initialize(bike:, organization:)
              @bike = bike
              @organization = organization
            end

            private

            def new_parking_notification
              @new_parking_notification ||= ::ParkingNotification.build_for(bike: @bike, organization: @organization)
            end

            def create_parking_notifications_path
              organization_parking_notifications_path(organization_id: @organization.to_param)
            end

            # Seeds the map pin when the browser location is unavailable
            def org_map_coordinates
              @org_map_coordinates ||= @organization.map_focus_coordinates
            end
          end
        end
      end
    end
  end
end
