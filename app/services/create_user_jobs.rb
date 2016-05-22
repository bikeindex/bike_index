class CreateUserJobs
  def initialize(user, email = nil)
    @user = user
    @email = email || @user.email
  end

  def associate_ownerships
    ownerships = Ownership.where(owner_email: @email)
    if ownerships.any?
      ownerships.each { |i| i.update_attributes(user_id: @user.id) }
    end
  end

  def associate_membership_invites(without_confirm: false)
    organization_invitations = OrganizationInvitation.where(invitee_email: @email)
    if organization_invitations.any?
      organization_invitations.each { |i| i.assign_to(@user) }
      @user.confirm(@user.confirmation_token) unless without_confirm
    end
  end

  def send_welcome_email
    EmailWelcomeWorker.perform_async(@user.id)
  end

  def send_confirmation_email
    EmailConfirmationWorker.perform_async(@user.id)
  end

  def perform_create_jobs
    associate_membership_invites # This may confirm the user. We auto-confirm users that belong to orgs
    if @user.confirmed
      send_welcome_email
      perform_confirmed_jobs
    else
      send_confirmation_email
    end
  end

  def perform_confirmed_jobs
    UserEmail.create_confirmed_primary_email(@user)
    associate_ownerships
  end

  def perform_associations
    associate_ownerships
    associate_membership_invites(without_confirm: true)
  end
end