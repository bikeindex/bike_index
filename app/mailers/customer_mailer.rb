class CustomerMailer < ActionMailer::Base

  default from: "\"Bike Index\" <contact@bikeindex.org>", :content_type => 'multipart/alternative', :parts_order => [ "text/calendar", "text/plain", "text/html", "text/enriched" ]

  def welcome_email(user)
    @user = user
    mail(:to => user.email, :subject => "Welcome to the Bike Index!") do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def confirmation_email(user)
    @user = user
    mail(:to => user.email, :subject => "Welcome to the Bike Index!") do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def password_reset_email(user)
    @user = user
    @url = "#{root_url}users/password_reset?token=#{user.password_reset_token}"
    mail(to: user.email, :subject => "Instructions to reset your password") do |format|
      format.text
      format.html { render layout: 'email' }
    end
  end

  def ownership_invitation_email(ownership)
    @ownership = ownership
    @bike = @ownership.bike
    @biketype = CycleType.find(@bike.cycle_type_id).name.downcase
    @new_bike = @bike.ownerships.count == 1
    @new_user = true unless User.fuzzy_email_find(@ownership.owner_email)
    @creation_org = @bike.creation_organization if @bike.creation_organization.present? && @new_bike
    if @bike.stolen
      subject = "Your stolen bike"
    else
      subject = "Claim your bike on BikeIndex.org!"
    end
    mail(to: @ownership.owner_email, subject: subject) do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def organization_invitation_email(organization_invitation)
    @organization_invitation = organization_invitation
    @organization = organization_invitation.organization
    @inviter = User.find(organization_invitation.inviter)
    @new_user = false
    @new_user = true unless User.fuzzy_email_find(@organization_invitation.invitee_email)
    mail(to: @organization_invitation.invitee_email, subject: "Join #{@organization.name} on the Bike Index") do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def bike_token_invitation_email(bt_invitation)
    @bike_token_invitation = bt_invitation
    @inviter = User.find(@bike_token_invitation.inviter_id)
    @new_user = true unless User.fuzzy_email_find(@bike_token_invitation.invitee_email)
    mail(to: @bike_token_invitation.invitee_email, from: @inviter.email, subject: @bike_token_invitation.subject) do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def stolen_notification_email(stolen_notification)
    @stolen_notification = stolen_notification
    mail(to: @stolen_notification.receiver.email, bcc: "admin@bikeindex.org", subject: @stolen_notification.subject) do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

end
