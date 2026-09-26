# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeBox
        # The alerts render outside the cache, since resolving or dismissing one doesn't touch
        # the bike. Each is loaded once for the page, and each box picks out its own
        class Component < ApplicationComponent
          def self.user_alerts(user)
            return [] unless user.alert_slugs.intersect?(UserAlert.account_kinds)

            user.user_alerts.active.account.includes(:organization)
          end

          def self.unfinished_b_params(bikes)
            BParam.acknowledgment_pending.where(created_bike_id: bikes.map(&:id)).order(:id).index_by(&:created_bike_id)
          end

          def initialize(bike:, current_user:, user_alerts: [], unfinished_b_params: {})
            @bike = bike
            @current_user = current_user
            @user_alerts = user_alerts.select { it.bike_id == bike.id }
            @unfinished_b_param = unfinished_b_params[bike.id]
          end

          private

          def cache_key
            [self.class.cache_digest, @bike]
          end
        end
      end
    end
  end
end
