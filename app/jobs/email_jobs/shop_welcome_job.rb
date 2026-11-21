# frozen_string_literal: true

module EmailJobs
  class ShopWelcomeJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(organization_id, user_id)
      organization = Organization.find_by(id: organization_id)
      user = User.find_by(id: user_id)
      return unless organization&.bike_shop? && user

      # One per organization, so a retry (or a second enqueue) resumes the same delivery
      notification = Notification.find_or_create_by(kind: "shop_welcome", notifiable: organization) { it.user = user }

      Notifications::Deliver.track_email(notification) { OrganizedMailer.shop_welcome(organization, user).deliver_now }
    end
  end
end
