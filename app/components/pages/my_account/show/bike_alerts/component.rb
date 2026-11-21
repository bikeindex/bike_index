# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeAlerts
        # In the grid these stack above the tiles, since an alert inside a cell stretches its row
        #
        # named: says which bike, for an alert that no longer sits next to it
        # under_card: tucked beneath the card above it, which hides its top edge
        class Component < ApplicationComponent
          def initialize(bike:, current_user:, user_alerts: [], unfinished_b_param: nil, named: false, under_card: false)
            @bike = bike
            @current_user = current_user
            @user_alerts = user_alerts
            @unfinished_b_param = unfinished_b_param
            @named = named
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
