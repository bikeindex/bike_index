class CreateUserJobs
  def initialize(user)
    @user = user
  end

  def associate_ownerships
    ownerships = Ownership.where(owner_email: @user.email)
    if ownerships.any?
      ownerships.each { |i| i.update_attributes(user_id: @user.id) }
    end
  end

  def associate_membership_invites
    organization_invitations = OrganizationInvitation.where(invitee_email: @user.email)
    if organization_invitations.any?
      organization_invitations.each { |i| i.assign_to(@user) }
      @user.confirm(@user.confirmation_token)
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
end