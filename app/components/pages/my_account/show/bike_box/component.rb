# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeBox
        # One of the account page's registrations. The alerts render outside the cache, since
        # resolving or dismissing one doesn't touch the bike
        class Component < ApplicationComponent
          ALERT_KINDS = %w[unassigned_bike_org unfinished_registration].freeze

          # Loaded once for the page; each box picks out its own
          def self.user_alerts(user)
            return [] unless user.alert_slugs.intersect?(ALERT_KINDS)

            user.user_alerts.active.where(kind: ALERT_KINDS).includes(:alertable, :organization).to_a
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
        end
      end
    end
  end
end
