# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeAlerts
        # Tucked under the card above: pulled up past the row's gap and the card's corner
        # radius, with the first alert padded back down by the same
        class Component < ApplicationComponent
          def initialize(bike:, user_alerts:)
            @bike = bike
            @user_alerts = user_alerts
          end

          def render? = @user_alerts.any?
        end
      end
    end
  end
end
