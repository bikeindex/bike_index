# frozen_string_literal: true

class Email::MarketplaceMessageJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  def perform(id)
    marketplace_message = MarketplaceMessage.find_by(id:)
    return if marketplace_message.blank?

    likely_spam = marketplace_message.likely_spam?
    kind = likely_spam ? :marketplace_message_blocked : :marketplace_message
    notification = marketplace_message.notifications.first
    notification ||= Notification.create(kind: "marketplace_message", notifiable: marketplace_message,
      user_id: likely_spam ? marketplace_message.sender_id : marketplace_message.receiver_id)
    # track_email_delivery returns if delivery_success, but return early here to prevent updating the cache
    return if notification.delivery_success?

    delivery = nil
    notification.track_email_delivery do
      delivery = if likely_spam
        AdminMailer.blocked_marketplace_message_email(marketplace_message).deliver_now
      else
        CustomerMailer.marketplace_message_notification(marketplace_message).deliver_now
      end
    end
    return if delivery.blank?

    # delivery = if marketplace_message.likely_spam?
    #   notify_admins_of_block(marketplace_message)
    # else
    #   notify_receiver(marketplace_message)
    # end
    # return if delivery.blank? # nothing was delivered

    # Bust caches on the associationsa
    marketplace_message.sender&.update(updated_at: Time.current)
    marketplace_message.receiver&.update(updated_at: Time.current)
    marketplace_message.marketplace_listing&.update(updated_at: Time.current)
    delivery
  end

  private

  def notify_receiver(marketplace_message)
    notification = marketplace_message.notifications.first
    notification ||= Notification.create(kind: "marketplace_message", notifiable: marketplace_message,
      user_id: marketplace_message.receiver_id)

    # track_email_delivery returns if delivery_success, but return early here to prevent updating the cache
    return if notification.delivery_success?

    delivery = nil
    notification.track_email_delivery do
      delivery = CustomerMailer.marketplace_message_notification(marketplace_message).deliver_now
    end

    delivery # so that we can check the actual email response in tests
  end

  def notify_admins_of_block(marketplace_message)
    notification = marketplace_message.notifications.first
    notification ||= Notification.create(kind: "marketplace_message_blocked", notifiable: marketplace_message,
      user_id: marketplace_message.sender_id)

    # track_email_delivery returns if delivery_success, but return early here to prevent updating the cache
    return if notification.delivery_success?

    delivery = nil
    notification.track_email_delivery do
      AdminMailer.blocked_marketplace_message_email(marketplace_message).deliver_now
    end

    delivery # so that we can check the actual email response in tests
  end

  #   kind = marketplace_message.likely_spam? ? "marketplace_message_blocked" : "marketplace_message"

  #   notification = Notification.find_or_create_by(notifiable: marketplace_message, kind:) do |n|
  #     n.user_id = marketplace_message.receiver_id unless kind == "marketplace_message_blocked"
  #   end

  #   # track_email_delivery returns if delivery_success, but return early here to prevent updating the cache
  #   return if notification.delivery_success?

  #   delivery = nil
  #   notification.track_email_delivery do
  #     delivery = if kind == "marketplace_message_blocked"
  #       AdminMailer.blocked_marketplace_message_email(marketplace_message).deliver_now
  #     else
  #       CustomerMailer.marketplace_message_notification(marketplace_message).deliver_now
  #     end
  #   end

  #   # Bust caches on the associations (only for non-blocked messages)
  #   unless kind == "marketplace_message_blocked"
  #     marketplace_message.sender&.update(updated_at: Time.current)
  #     marketplace_message.receiver&.update(updated_at: Time.current)
  #     marketplace_message.marketplace_listing&.update(updated_at: Time.current)
  #   end

  #   delivery # so that we can check the actual email response in tests
  # end
end
