# TODO: eventually this should merge with after_user_change_worker.rb, or something
class AfterUserCreateWorker < ApplicationWorker
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
    associate_membership_invites(user, email)
    send_welcoming_email(user)
    AfterUserCreateWorker.perform_async(user.id, "async")
  end

  def perform_merged_jobs(user, email)
    # This is already performing in a background job, so we don't need to run async
    # Also, we we need to process with the previous email, not the user's current email
    associate_membership_invites(user, email, without_confirm: true)
    associate_ownerships(user, email)
  end

  def perform_confirmed_jobs(user, email)
    UserEmail.create_confirmed_primary_email(user)
    AfterUserCreateWorker.perform_async(user.id, "async")
  end

  def perform_async_jobs(user, email)
    # These jobs don't need to happen immediately
    import_user_attributes(user)
    associate_ownerships(user, email) if user.confirmed?
  end

  def send_welcoming_email(user)
    # If the user is confirmed, send the welcome email, otherwise send the confirmation email
    if user.confirmed?
      EmailWelcomeWorker.perform_async(user.id)
    else
      EmailConfirmationWorker.perform_in(1.second, user.id)
    end
  end

  def associate_ownerships(user, email)
    Ownership.where(owner_email: email).each do |ownership|
      ownership.update_attributes(user_id: user.id)
    end
  end

  def associate_membership_invites(user, email, without_confirm: false)
    memberships = Membership.unclaimed.where(invited_email: email)
    return false unless memberships.any?

    first, *rest = memberships.pluck(:id)
    ProcessMembershipWorker.new.perform(first, user.id)

    # We want to do the first one inline so we can redirect
    # the user to the org page
    rest.each do |membership_id|
      ProcessMembershipWorker.perform_async(membership_id, user.id)
    end

    user.confirm(user.confirmation_token) unless without_confirm
  end

  def import_user_attributes(user)
    if user.phone.blank?
      user.phone = user_bikes_for_attrs(user.id).map { |b| b.phone }.reject(&:blank?).last
    end
    # Only do address import if the user doesn't have an address present
    unless [user.street, user.city, user.zipcode, user.state, user.country].reject(&:blank?).any?
      address = user_bikes_for_attrs(user.id).map { |b| b.address_hash }.reject(&:blank?).last
      user.attributes = address.merge(skip_geocoding: true) if address.present?
    end
    user.save if user.changed?
  end

  private

  def user_bikes_for_attrs(user_id)
    # Deal with example bikes
    Ownership.where(user_id: user_id).where.not(user_id: nil).order(:created_at).pluck(:bike_id)
      .map { |id| Bike.unscoped.where(id: id).first }.compact
  end
end
