# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module Wrapper
        # The alerts about the registration's current state, rendered above the page
        # body in both the consumer and org admin views. TokenAlert is the way back to
        # the dialog TokenPrompt opens, which lives outside this page's fragment cache
        class Component < ApplicationComponent
          def initialize(bike:, current_user: nil, bike_sticker: nil, owner: false, current_alerts: nil)
            @bike = bike
            @current_user = current_user
            @bike_sticker = bike_sticker
            @owner = owner
            @current_alerts = current_alerts
          end
        end
      end
    end
  end
end
