# frozen_string_literal: true

module Registrations
  module Show
    module OrgTopActions
      module ParkingNotificationForm
        # Org-admin parking-notification / impound form panel. Rendered inside the
        # org-admin action-panel accordion (data-panel-name="parking"). Two Stimulus
        # controllers drive it: `...-parking-notification-show` on the panel retitles
        # for impound and relays which trigger opened it, and `...-form` on the form
        # itself wires up the map pin, geolocation and the address fields
        class Component < ApplicationComponent
          SHOW_CONTROLLER = "registrations--show--parking-notification-show"
          FORM_CONTROLLER = "registrations--show--parking-notification-form"

          def initialize(bike:, organization:)
            @bike = bike
            @organization = organization
          end

          private

          # The form's own controller, alongside the two it already carries, plus the
          # mode the panel relays on window (the form is a descendant, so `shown`
          # can't bubble down to it)
          def form_data
            {
              controller: "csrf-refresh form-persist #{FORM_CONTROLLER}",
              "form-persist-key-value": "parking-notification-#{@bike.id}",
              "#{FORM_CONTROLLER}-default-kind-value": new_parking_notification.kind,
              "#{FORM_CONTROLLER}-mapbox-key-value": ENV["MAPBOX_MAPPING"],
              "#{FORM_CONTROLLER}-style-url-value": MAPS_STYLE_URL,
              "#{FORM_CONTROLLER}-org-latitude-value": org_map_coordinates[:latitude],
              "#{FORM_CONTROLLER}-org-longitude-value": org_map_coordinates[:longitude],
              action: "input->form-persist#save submit->form-persist#clear " \
                "#{SHOW_CONTROLLER}:mode@window->#{FORM_CONTROLLER}#applyMode"
            }
          end

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

          # Seeds the map pin when the browser location is unavailable
          def org_map_coordinates
            @org_map_coordinates ||= @organization.map_focus_coordinates
          end
        end
      end
    end
  end
end
