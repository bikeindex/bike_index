# frozen_string_literal: true

module Pages
  module Org
    module ParkingNotifications
      module New
        # A parking notification for a vehicle that isn't registered, which registers it as
        # it records the notification - always one page, whatever the registration form
        # settings say, and with the serial optional
        class Component < ApplicationComponent
          def initialize(organization:)
            @organization = organization
          end

          private

          def cycle_type_options
            CycleType.select_options(traditional_bike: true).map { |display, value| {display:, value:} }
          end

          def kind_entries
            ParkingNotification.kinds.map { {value: it, label: ParkingNotification.kinds_humanized[it.to_sym]} }
          end

          def form_data
            coordinates = @organization.map_focus_coordinates

            {controller: "org--parking-notification-form", action: "submit->org--parking-notification-form#clearMapState",
             "org--parking-notification-form-standalone-value": true,
             "org--parking-notification-form-org-latitude-value": coordinates[:latitude],
             "org--parking-notification-form-org-longitude-value": coordinates[:longitude]}
          end
        end
      end
    end
  end
end
