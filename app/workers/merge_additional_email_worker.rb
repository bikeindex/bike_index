class MergeAdditionalEmailWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true

  def perform(user_email_id)
    user_email = UserEmail.find(user_email_id)
    return true unless user_email.confirmed
    old_user = find_old_user(user_email.email, user_email.user_id)
    merge_old_user(user_email, old_user) if old_user.present?
    CreateUserJobs.new(user_email.user, user_email.email).perform_associations
  end

  def merge_old_user(user_email, old_user)
    user_email.update_attribute :old_user_id, old_user.id
    merge_user_memberships(user_email, old_user)
    old_user.ownerships.each { |i| i.update_attribute :user_id, user_email.user_id }
    old_user.created_ownerships.each { |i| i.update_attribute :creator_id, user_email.user_id }
    old_user.created_bikes.each { |i| i.update_attribute :creator_id, user_email.user_id }

    old_user.locks.each { |i| i.update_attribute :user_id, user_email.user_id }
    old_user.payments.each { |i| i.update_attribute :user_id, user_email.user_id }
    old_user.integrations.each { |i| i.update_attribute :user_id, user_email.user_id }
    old_user.sent_stolen_notifications.each { |i| i.update_attribute :sender_id, user_email.user_id }
    old_user.received_stolen_notifications.each { |i| i.update_attribute :receiver_id, user_email.user_id }
    Doorkeeper::Application.where(owner_id: old_user.id).each { |i| i.update_attribute :owner_id, user_email.user_id }
    CustomerContact.where(user_id: old_user.id).each { |i| i.update_attribute :user_id, user_email.user_id }
    CustomerContact.where(creator_id: old_user.id).each { |i| i.update_attribute :creator_id, user_email.user_id }
    old_user.reload # so we don't trigger dependent destroys
    old_user.destroy
  end

  def merge_user_memberships(user_email, old_user)
    Organization.where(auto_user_id: old_user.id).each { |i| i.update_attribute :auto_user_id, user_email.user_id }
    OrganizationInvitation.where(inviter_id: old_user.id).each { |i| i.update_attribute :inviter_id, user_email.user_id }
    OrganizationInvitation.where(invitee_id: old_user.id).each { |i| i.update_attribute :invitee_id, user_email.user_id }
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
    user_email = UserEmail.where('user_id != ?', user_id).where(email: email).first
    user_email && user_email.user
  end
end
