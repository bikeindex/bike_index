class MergeAdditionalEmailJob < ApplicationJob
  sidekiq_options queue: "high_priority"

  def perform(user_email_id)
    user_email = UserEmail.find(user_email_id)
    return true unless user_email.confirmed?
    old_user = find_old_user(user_email.email, user_email.user_id)
    merge_old_user(user_email, old_user) if old_user.present?
    ::Callbacks::AfterUserCreateJob.new.perform(user_email.user_id, "merged", user: user_email.user, email: user_email.email)
  end

  def merge_old_user(user_email, old_user)
    user_email.update_attribute(:old_user_id, old_user.id)
    merge_user_organization_roles(user_email, old_user)
    user_id = user_email.user_id
    old_user.ownerships.each { |i| i.update_attribute(:user_id, user_id) }
    old_user.created_ownerships.each { |i| i.update_attribute(:creator_id, user_id) }
    old_user.created_bikes.each { |i| i.update_attribute(:creator_id, user_id) }

    old_user.user_phones.update_all(user_id:)
    old_user.locks.update_all(user_id:)
    old_user.payments.update_all(user_id:)
    old_user.stripe_subscriptions.update_all(user_id:)
    old_user.memberships.update_all(user_id:)
    old_user.integrations.update_all(user_id:)
    old_user.sent_stolen_notifications.update_all(sender_id: user_id)
    old_user.received_stolen_notifications.update_all(receiver_id: user_id)
    old_user.theft_alerts.update_all(user_id:)
    old_user.bike_sticker_updates.update_all(user_id:)

    BikeVersion.unscoped.where(owner_id: old_user.id).each { |i| i.update(owner_id: user_id) }
    Doorkeeper::Application.where(owner_id: old_user.id).each { |i| i.update_attribute(:owner_id, user_id) }
    CustomerContact.where(user_id: old_user.id).each { |i| i.update_attribute(:user_id, user_id) }
    CustomerContact.where(creator_id: old_user.id).each { |i| i.update_attribute(:creator_id, user_id) }
    update_address_records(user_id, old_user.id)

    # Marketplace things
    MarketplaceListing.unscoped.where(seller_id: old_user.id).each { |i| i.update(seller_id: user_id) }
    MarketplaceListing.unscoped.where(buyer_id: old_user.id).each { |i| i.update(buyer_id: user_id) }

    # No index, so update all
    BikeSticker.where(user_id: old_user.id).update_all(user_id:)
    GraduatedNotification.where(user_id: old_user.id).update_all(user_id:)
    ParkingNotification.where(user_id: old_user.id).update_all(user_id:)

    if user_email.user.stripe_id.blank? && old_user.stripe_id.present?
      user_email.user.update(stripe_id: old_user.stripe_id)
    end
    user_email.user.update(banned: true) if old_user.banned?

    old_user.reload # so we don't trigger dependent destroys
    old_user.destroy
  end

  private

  def update_address_records(user_id, old_user_id)
    # If the new user has an
    if AddressRecord.user.where(user_id:).none?
      AddressRecord.user.where(user_id: old_user_id).each { |i| i.update(user_id:) }
    end
    AddressRecord.not_user.where(user_id: old_user_id).each { |i| i.update(user_id:) }
  end

  def merge_user_organization_roles(user_email, old_user)
    Organization.where(auto_user_id: old_user.id).each { |i| i.update_attribute :auto_user_id, user_email.user_id }
    OrganizationRole.where(sender_id: old_user.id).each { |i| i.update_attribute :sender_id, user_email.user_id }
    old_user.organization_roles.each do |organization_role|
      if user_email.user.organizations.include?(organization_role.organization)
        organization_role.delete
      else
        organization_role.update_attribute :user_id, user_email.user_id
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
