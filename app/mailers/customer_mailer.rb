class CustomerMailer < ActionMailer::Base

  default from: "\"Bike Index\" <contact@bikeindex.org>",
    content_type: 'multipart/alternative',
    parts_order: [ "text/calendar", "text/plain", "text/html", "text/enriched" ]
 
  def add_snippet(opts={})
    snippet = MailSnippet.matching_opts(opts.merge({mailer_method: @_action_name}))
    @snippet_body = snippet.body if snippet.present?
  end

  def welcome_email(user)
    @user = user
    mail(to: user.email, subject: "Welcome to the Bike Index!") do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end


  def confirmation_email(user)
    @user = user
    mail(to: user.email, subject: "Welcome to the Bike Index!") do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def invoice_email(payment)
    @payment = payment
    mail(to: payment.email, subject: "Thank you for supporting the Bike Index!") do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def stolen_bike_alert_email(customer_contact)
    @customer_contact = customer_contact
    @info = customer_contact.info_hash
    @bike = customer_contact.bike
    @biketype = CycleType.find(@bike.cycle_type_id).name.downcase
    mail(to: @customer_contact.user_email, from: @customer_contact.creator_email, subject: @customer_contact.title) do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def admin_contact_stolen_email(customer_contact)
    @customer_contact = customer_contact
    mail(to: @customer_contact.user_email, from: @customer_contact.creator_email, subject: @customer_contact.title) do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def password_reset_email(user)
    @user = user
    @url = "#{root_url}users/password_reset?token=#{user.password_reset_token}"
    mail(to: user.email, subject: "Instructions to reset your password") do |format|
      format.text
      format.html { render layout: 'email' }
    end
  end

  def ownership_invitation_email(ownership)
    @ownership = ownership
    @bike = @ownership.bike
    @new_pos_registration = true if @bike.registered_new && @bike.ownerships.count == 1
    @biketype = CycleType.find(@bike.cycle_type_id).name.downcase
    @new_bike = @bike.ownerships.count == 1
    @new_user = true unless User.fuzzy_email_find(@ownership.owner_email)
    @creation_org = @bike.creation_organization if @bike.creation_organization.present? && @new_bike
    if @bike.stolen
      subject = "Your stolen bike"
    else
      subject = "Claim your bike on BikeIndex.org!"
    end
    add_snippet({bike: @bike})
    mail(to: @ownership.owner_email, subject: subject) do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def organizationInvitation_email(organizationInvitation)
    @organizationInvitation = organizationInvitation
    @organization = organizationInvitation.organization
    @inviter = User.find(organizationInvitation.inviter)
    @new_user = false
    @new_user = true unless User.fuzzy_email_find(@organizationInvitation.invitee_email)
    mail(to: @organizationInvitation.invitee_email, subject: "Join #{@organization.name} on the Bike Index") do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def stolenNotification_email(stolenNotification)  
    @stolenNotification = stolenNotification
    mail(to: "#{@stolenNotification.receiver_email}, bryan@bikeindex.org", from: "bryan@bikeindex.org", subject: @stolenNotification.display_subject) do |format|
      format.text
      format.html { render layout: 'email'}
    end
    stolenNotification.update_attribute :send_dates, stolenNotification.send_dates << Time.now.to_i
  end

end