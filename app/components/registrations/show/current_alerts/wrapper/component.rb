# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module Wrapper
        # The alerts about the registration's current state, rendered above the page
        # body in both the consumer and org admin views. The token-scoped ones come
        # from BikeServices::ShowAlerts, resolved per request by the controller
        class Component < ApplicationComponent
          NO_ALERTS = BikeServices::ShowAlerts::Resolved.new(claim_message: nil, token: nil,
            token_type: nil, matching_notification: nil, recovered_stolen_record: nil)

          def initialize(bike:, current_user: nil, bike_sticker: nil, owner: false, alerts: nil)
            @bike = bike
            @current_user = current_user
            @bike_sticker = bike_sticker
            @owner = owner
            @alerts = alerts || NO_ALERTS
          end

          private

          # Like the legacy overlays, only one prompt opens — they're all modals, and
          # stacking dialogs would bury each other. Recovery wins over a notification
          # (the legacy partial let it override), and claiming is the fallback
          def token_prompt
            @token_prompt ||= [
              RecoveryPrompt::Component.new(bike: @bike, stolen_record: @alerts.recovered_stolen_record),
              NotificationToken::Component.new(bike: @bike, token: @alerts.token,
                token_type: @alerts.token_type, matching_notification: @alerts.matching_notification),
              ClaimInvitation::Component.new(bike: @bike, current_user: @current_user,
                claim_message: @alerts.claim_message)
            ].find(&:render?)
          end
        end
      end
    end
  end
end
