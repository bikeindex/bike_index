# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeAlerts
        # under_card: tucked beneath the card above it, which hides its top edge
        class Component < ApplicationComponent
          def initialize(bike:, current_user:, user_alerts: [], unfinished_b_param: nil, under_card: false)
            @bike = bike
            @current_user = current_user
            @user_alerts = user_alerts
            @unfinished_b_param = unfinished_b_param
            @under_card = under_card
          end

          def render? = @unfinished_b_param.present? || @user_alerts.any?

          private

          # Pulled up past the row's gap and the card's corner radius, padded back down by the same
          def alert_margin_classes(index)
            (@under_card && index.zero?) ? "tw:mb-0 tw:pt-6.5!" : "tw:mb-0"
          end
        end
      end
    end
  end
end
