# TODO: eventually this should merge with after_user_change_worker.rb, or something
class Callbacks::AfterUserCreateJob < ApplicationJob
  sidekiq_options queue: "high_priority"

  # Generally, this is called inline - so it makes sense to pass in the user rather than just the user_id
  def perform(user_id, job_stage, user: nil, email: nil)
    user ||= User.find(user_id)
    user.skip_update = true
    email ||= user.email
    if job_stage == "new"
      perform_create_jobs(user, email)
    elsif job_stage == "confirmed"
      perform_confirmed_jobs(user, email)
    elsif job_stage == "merged"
      perform_merged_jobs(user, email)
    elsif job_stage == "async"
      perform_async_jobs(user, email)
    end
  end

  def perform_create_jobs(user, email)
    # This may confirm the user. We auto-confirm users that belong to orgs.
    # Auto confirming the user actually ends up running perform_confirmed_jobs.
    associate_organization_role_invites(user, email)
    send_welcoming_email(user)
    ::Callbacks::AfterUserCreateJob.perform_async(user.id, "async")
  end

  def perform_merged_jobs(user, email)
    # This is already performing in a background job, so we don't need to run async
    # Also, we we need to process with the previous email, not the user's current email
    associate_organization_role_invites(user, email, skip_confirm: true)
    associate_ownerships(user, email)
  end

  def perform_confirmed_jobs(user, email)
    UserEmail.create_confirmed_primary_email(user)
    create_passwordless_domain_organization_roles(user)
    ::Callbacks::AfterUserCreateJob.perform_async(user.id, "async")
  end

  def perform_async_jobs(user, email)
    # These jobs don't need to happen immediately
    import_user_attributes(user)
    if user.confirmed?
      associate_ownerships(user, email)
      associate_graduated_notifications(user.reload)
    end
  end

  def send_welcoming_email(user)
    # If the user is confirmed, send the welcome email, otherwise send the confirmation email
    if user.confirmed?
      Email::WelcomeJob.perform_async(user.id)
    else
      Email::ConfirmationJob.perform_in(1.second, user.id)
    end
  end

  def associate_ownerships(user, email)
    Ownership.where(owner_email: email).each do |ownership|
      ownership.update(user_id: user.id)
    end
  end

  def associate_graduated_notifications(user)
    GraduatedNotification.where(bike_id: user.bike_ids, user_id: nil)
      .update_all(user_id: user.id)
  end

  def associate_organization_role_invites(user, email, skip_confirm: false)
    organization_roles = OrganizationRole.unclaimed.where(invited_email: email)
    return false unless organization_roles.any?

    first, *rest = organization_roles.pluck(:id)
    Users::ProcessOrganizationRoleJob.new.perform(first, user.id)

    # We want to do the first one inline so we can redirect
    # the user to the org page
    rest.each do |organization_role_id|
      Users::ProcessOrganizationRoleJob.perform_async(organization_role_id, user.id)
    end

    user.confirm(user.confirmation_token) unless skip_confirm
  end

  def import_user_attributes(user)
    if user.phone.blank?
      user.phone = user_bikes_for_attrs(user.id).map { |b| b.phone }.reject(&:blank?).last
      user.save if user.phone.present?
    end
    # Only do address import if the user doesn't have an address present
    unless user.address_present?
      ::Callbacks::AfterUserChangeJob.assign_user_address_from_bikes(user, bikes: user_bikes_for_attrs(user.id),
        save_user: true)
    end
  end

  private

  def user_bikes_for_attrs(user_id)
    # Deal with example bikes
    bike_ids = Ownership.where(user_id: user_id).where.not(user_id: nil).order(:created_at).limit(100).pluck(:bike_id)
    Bike.unscoped.where(id: bike_ids)
  end

  def create_passwordless_domain_organization_roles(user)
    matching_organization = Organization.passwordless_email_matching(user.email)
    return false unless matching_organization.present?
    return false if user.organization_roles.pluck(:organization_id).include?(matching_organization.id)

    OrganizationRole.create_passwordless(organization_id: matching_organization.id,
      invited_email: user.email)
    user.reload
  end
end
