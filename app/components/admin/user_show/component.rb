# frozen_string_literal: true

module Admin::UserShow
  class Component < ApplicationComponent
    def initialize(user:, bikes:, bikes_count:)
      @user = user
      @bikes = bikes
      @bikes_count = bikes_count
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
