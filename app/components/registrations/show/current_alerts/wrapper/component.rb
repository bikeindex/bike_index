# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module Wrapper
        # The alerts about the registration's current state, rendered above the page
        # body in both the consumer and org admin views. The token-scoped ones come
        # from BikeServices::ShowAlerts, resolved per request by the controller
        class Component < ApplicationComponent
          def initialize(bike:, current_user: nil, bike_sticker: nil, owner: false, alerts: nil)
            @bike = bike
            @current_user = current_user
            @bike_sticker = bike_sticker
            @owner = owner
            @alerts = alerts || BikeServices::ShowAlerts::Resolved.new(claim_message: nil, token: nil,
              token_type: nil, matching_notification: nil, recovered_stolen_record: nil)
          end
        end
      end
    end
  end
end
