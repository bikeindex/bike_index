# frozen_string_literal: true

class Email::MarketplaceMessageJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  def perform(id)
    marketplace_message = MarketplaceMessage.find_by(id:)
    return if marketplace_message.blank?

    notification = marketplace_message.notifications.first
    notification ||= Notification.create(kind: "marketplace_message", notifiable: marketplace_message,
      user_id: marketplace_message.receiver_id)

    # track_email_delivery returns if delivery_success, but return early here to prevent updating the cache
    return if notification.delivery_success?

    notification.track_email_delivery do
      CustomerMailer.marketplace_message_notification(marketplace_message).deliver_now
    end

    # Bust caches on the associations
    marketplace_message.sender&.update(updated_at: Time.current)
    marketplace_message.receiver&.update(updated_at: Time.current)
  end
end
