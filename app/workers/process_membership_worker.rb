class ProcessMembershipWorker
  include Sidekiq::Worker
  sidekiq_options queue: "high_priority", backtrace: true

  def perform(membership_id, user_id = nil)
    membership = Membership.find(membership_id)

    assign_membership_user(membership, user_id) if membership.user.blank?
    if membership.send_invitation_email?
      OrganizedMailer.organization_invitation(membership).deliver_now
      membership.update_attribute :email_invitation_sent_at, Time.current
    end
    # Bust cache keys on user and organization
    membership.user&.update_attributes(updated_at: Time.current)
    membership.organization.update_attributes(updated_at: Time.current) if membership.organization.present?

    assign_all_ambassador_tasks_to(membership)
  end

  def assign_membership_user(membership, user_id)
    user_id ||= User.fuzzy_email_find(membership.invited_email)&.id
    return false unless user_id.present?
    membership.update_attributes(user_id: user_id)
    membership.reload
  end

  def assign_all_ambassador_tasks_to(membership)
    return unless membership.ambassador?
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
