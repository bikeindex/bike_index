class CreateUserJobs
  def initialize(creation_params = nil)
    @user = creation_params ? creation_params[:user] : nil
  end

  def associate_ownerships
    ownerships = Ownership.where(["lower(owner_email) = ?", @user.email.downcase.strip])
    if ownerships.any?
      ownerships.each { |i| i.update_attributes(user_id: @user.id) }
    end
  end

  def associate_token_invites
    bike_token_invitations = BikeTokenInvitation.where(["lower(invitee_email) = ?", @user.email.downcase.strip])
    if bike_token_invitations.any?
      bike_token_invitations.each { |i| i.assign_to(@user) }
    end
  end

  def associate_membership_invites
    organization_invitations = OrganizationInvitation.where(["lower(invitee_email) = ?", @user.email.downcase.strip])
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

  def do_jobs
    associate_ownerships
    associate_token_invites
    associate_membership_invites

    if @user.confirmed 
      send_welcome_email
    else
      send_confirmation_email
    end
  end

end