class Users::ProcessOrganizationRoleJob < ApplicationJob
  sidekiq_options queue: "high_priority"

  def perform(organization_role_id, user_id = nil)
    organization_role = OrganizationRole.find_by(id: organization_role_id)
    return if organization_role.blank?

    assign_organization_role_user(organization_role, user_id) if organization_role.user.blank?
    return false if remove_duplicated_organization_role!(organization_role)
    auto_generate_user_for_organization(organization_role)
    if organization_role.send_invitation_email?
      OrganizedMailer.organization_invitation(organization_role).deliver_now
      organization_role.update(email_invitation_sent_at: Time.current, skip_processing: true)
    end

    # Bust cache keys on user and organization
    organization_role.user&.update(updated_at: Time.current, skip_update: true)
    organization_role.organization.update(updated_at: Time.current, skip_update: true) if organization_role.organization.present?

    # Assign ambassador tasks too
    if organization_role.ambassador? && organization_role.user.present?
      assign_all_ambassador_tasks_to(organization_role)
    end
  end

  def assign_organization_role_user(organization_role, user_id)
    user_id ||= User.fuzzy_confirmed_or_unconfirmed_email_find(organization_role.invited_email)&.id
    return false unless user_id.present?
    organization_role.update(user_id: user_id)
    organization_role.reload
    User.find_by_id(user_id)&.update(updated_at: Time.current)
  end

  def remove_duplicated_organization_role!(organization_role)
    return false unless organization_role.user.present? &&
      organization_role.user.organization_roles.where.not(id: organization_role.id)
        .where(organization_id: organization_role.organization_id).any?
    organization_role.destroy
  end

  def auto_generate_user_for_organization(organization_role)
    return false unless organization_role.organization.enabled?("passwordless_users") &&
      organization_role.user.blank?
    password = SecurityTokenizer.new_password_token
    user = User.new(skip_update: true,
      email: organization_role.invited_email,
      password: password,
      password_confirmation: password)
    user.save!
    user.confirm(user.confirmation_token)
    # We don't want to send users emails in this situation.
    organization_role.update(user_id: user.id, email_invitation_sent_at: Time.current)
    organization_role.reload
  end

  def assign_all_ambassador_tasks_to(organization_role)
    ambassador = organization_role.user.becomes(Ambassador)

    already_assigned_task_ids =
      AmbassadorTask
        .includes(ambassador_task_assignments: :ambassador)
        .where(ambassador_task_assignments: {user_id: ambassador.id})
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
