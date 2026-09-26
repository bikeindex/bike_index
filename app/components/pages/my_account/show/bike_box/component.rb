# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeBox
        # One of the account page's registrations. The alerts render outside the cache, since
        # resolving or dismissing one doesn't touch the bike
        class Component < ApplicationComponent
          # Loaded once for the page; each box picks out its own
          def self.user_alerts(user)
            return [] unless user.alert_slugs.intersect?(UserAlert.account_kinds)

            user.user_alerts.active.account.includes(:organization).to_a
          end

          def initialize(bike:, current_user:, user_alerts: [])
            @bike = bike
            @current_user = current_user
            @user_alerts = user_alerts.select { it.bike_id == bike.id }
          end

          private

          def cache_key
            [self.class.cache_digest, @bike]
          end

          def unfinished_b_param
            @bike.b_params.acknowledgment_pending.last if @bike.unfinished_registration?
          end
        end
      end
    end
  end
end
