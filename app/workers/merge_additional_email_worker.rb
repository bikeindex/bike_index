class MergeAdditionalEmailWorker < ApplicationWorker
  sidekiq_options queue: "high_priority"

  def perform(user_email_id)
    user_email = UserEmail.find(user_email_id)
    return true unless user_email.confirmed?
    old_user = find_old_user(user_email.email, user_email.user_id)
    merge_old_user(user_email, old_user) if old_user.present?
    AfterUserCreateWorker.new.perform(user_email.user_id, "merged", user: user_email.user, email: user_email.email)
  end

  def merge_old_user(user_email, old_user)
    user_email.update_attribute :old_user_id, old_user.id
    merge_user_memberships(user_email, old_user)
    old_user.ownerships.each { |i| i.update_attribute :user_id, user_email.user_id }
    old_user.created_ownerships.each { |i| i.update_attribute :creator_id, user_email.user_id }
    old_user.created_bikes.each { |i| i.update_attribute :creator_id, user_email.user_id }

    old_user.user_phones.update_all(user_id: user_email.user_id)
    old_user.locks.update_all(user_id: user_email.user_id)
    old_user.payments.update_all(user_id: user_email.user_id)
    old_user.integrations.update_all(user_id: user_email.user_id)
    old_user.sent_stolen_notifications.update_all(sender_id: user_email.user_id)
    old_user.received_stolen_notifications.update_all(receiver_id: user_email.user_id)
    old_user.theft_alerts.update_all(user_id: user_email.user_id)
    old_user.bike_sticker_updates.update_all(user_id: user_email.user_id)

    BikeSticker.where(user_id: old_user.id).update_all(user_id: user_email.user_id)
    GraduatedNotification.where(user_id: old_user.id).update_all(user_id: user_email.user_id)
    ParkingNotification.where(user_id: old_user.id).update_all(user_id: user_email.user_id)

    Doorkeeper::Application.where(owner_id: old_user.id).each { |i| i.update_attribute :owner_id, user_email.user_id }
    CustomerContact.where(user_id: old_user.id).each { |i| i.update_attribute :user_id, user_email.user_id }
    CustomerContact.where(creator_id: old_user.id).each { |i| i.update_attribute :creator_id, user_email.user_id }

    user_email.user.update(banned: true) if old_user.banned?

    old_user.reload # so we don't trigger dependent destroys
    old_user.destroy
  end

  def merge_user_memberships(user_email, old_user)
    Organization.where(auto_user_id: old_user.id).each { |i| i.update_attribute :auto_user_id, user_email.user_id }
    Membership.where(sender_id: old_user.id).each { |i| i.update_attribute :sender_id, user_email.user_id }
    old_user.memberships.each do |membership|
      if user_email.user.organizations.include?(membership.organization)
        membership.delete
      else
        membership.update_attribute :user_id, user_email.user_id
      end
    end
  end

  def find_old_user(email, user_id)
    user = User.fuzzy_unconfirmed_primary_email_find(email)
    return user if user.present?
    user_email = UserEmail.where("user_id != ?", user_id).where(email: email).first
    user_email&.user
  end
end
