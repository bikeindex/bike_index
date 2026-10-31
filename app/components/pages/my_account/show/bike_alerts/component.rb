# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeAlerts
        # In the grid these stack above the tiles, since an alert inside a cell stretches its row
        #
        # named: says which bike, for an alert that no longer sits next to it
        class Component < ApplicationComponent
          def initialize(bike:, current_user:, user_alerts: [], unfinished_b_param: nil, named: false)
            @bike = bike
            @current_user = current_user
            @user_alerts = user_alerts
            @unfinished_b_param = unfinished_b_param
            @named = named
          end

          def render? = @unfinished_b_param.present? || @user_alerts.any?
        end
      end
    end
  end
end
