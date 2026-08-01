# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module Wrapper
        # The alerts about the registration's current state, in both views. The token
        # prompt is the alert here — its dialog renders outside the page's fragment cache
        class Component < ApplicationComponent
          def initialize(bike:, current_user: nil, bike_sticker: nil, owner: false, current_alerts: nil)
            @bike = bike
            @current_user = current_user
            @bike_sticker = bike_sticker
            @owner = owner
            @current_alerts = current_alerts
          end

          # Each renders itself or nothing, so this is only the order they stack in
          def call
            safe_join([
              render(TokenPrompt::Component.new(bike: @bike, current_user: @current_user,
                current_alerts: @current_alerts, variant: :alert)),
              render(ScannedSticker::Component.new(bike: @bike, bike_sticker: @bike_sticker, current_user: @current_user)),
              render(SentToNewOwner::Component.new(bike: @bike, owner: @owner))
            ])
          end
        end
      end
    end
  end
end
