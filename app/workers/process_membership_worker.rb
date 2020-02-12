class ProcessMembershipWorker < ApplicationWorker
  sidekiq_options queue: "high_priority"

  def perform(membership_id, user_id = nil)
    membership = Membership.find(membership_id)

    assign_membership_user(membership, user_id) if membership.user.blank?
    return false if remove_duplicated_membership!(membership)
    auto_generate_user_for_organization(membership)
    if membership.send_invitation_email?
      OrganizedMailer.organization_invitation(membership).deliver_now
      membership.update_attribute :email_invitation_sent_at, Time.current
    end

    # Bust cache keys on user and organization
    membership.user&.update_attributes(updated_at: Time.current)
    membership.organization.update_attributes(updated_at: Time.current) if membership.organization.present?

    # Assign ambassador tasks too
    if membership.ambassador? && membership.user.present?
      assign_all_ambassador_tasks_to(membership)
    end
  end

  def assign_membership_user(membership, user_id)
    user_id ||= User.fuzzy_confirmed_or_unconfirmed_email_find(membership.invited_email)&.id
    return false unless user_id.present?
    membership.update_attributes(user_id: user_id)
    membership.reload
  end

  def remove_duplicated_membership!(membership)
    return false unless membership.user.present? &&
                        membership.user.memberships.where.not(id: membership.id)
                                  .where(organization_id: membership.organization_id).any?
    membership.destroy
  end

  def auto_generate_user_for_organization(membership)
    return false unless membership.organization.enabled?("passwordless_users") &&
                        membership.user.blank?
    password = SecurityTokenizer.new_password_token
    user = User.new(skip_create_jobs: true,
                    email: membership.invited_email,
                    password: password,
                    password_confirmation: password)
    user.save!
    user.confirm(user.confirmation_token)
    # We don't want to send users emails in this situation.
    membership.update_attributes(user_id: user.id, email_invitation_sent_at: Time.current)
    membership.reload
  end

  def assign_all_ambassador_tasks_to(membership)
    ambassador = membership.user.becomes(Ambassador)

    already_assigned_task_ids =
      AmbassadorTask
        .includes(ambassador_task_assignments: :ambassador)
        .where(ambassador_task_assignments: { user_id: ambassador.id })
        .select(:id)

    new_assignments =
      AmbassadorTask
        .includes(:ambassador_task_assignments)
        .where
        .not(id: already_assigned_task_ids)
        .references(:ambassador_task_assignments)

    new_assignments.find_each do |ambassador_task|
      ambassador_task.assign_to(ambassador)
    end
  end
end
