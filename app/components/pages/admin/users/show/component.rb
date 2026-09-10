# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Show
        class Component < ApplicationComponent
          def initialize(user:, bikes:, bikes_count:, current_country_id: nil, display_dev_info: false)
            @user = user
            @bikes = bikes
            @bikes_count = bikes_count
            @current_country_id = current_country_id
            @display_dev_info = display_dev_info
          end

          private

          def object_limit
            10
          end

          def marketplace_messages
            MarketplaceMessage.where(sender_id: @user.id).order(id: :desc)
          end

          def memberships
            Membership.where(user_id: @user.id).order(id: :desc)
          end

          def user_alerts
            @user.user_alerts.order(created_at: :desc)
          end

          def payments
            @user.payments.reorder(created_at: :desc).paid
          end

          def mailchimp_datum
            @user.mailchimp_datum
          end
        end
      end
    end
  end
end
