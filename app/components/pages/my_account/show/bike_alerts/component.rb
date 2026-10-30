# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeAlerts
        # What a registration needs the owner to do: finish registering, or join the
        # organization their other bikes belong to. Beside its card in the list; in the grid
        # they stack above it instead, since a tile can't grow without stretching its row.
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
