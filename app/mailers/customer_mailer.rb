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
    @url = "#{ENV['BASE_URL']}/users/password_reset?token=#{user.password_reset_token}"
    mail(to: user.email, subject: "Instructions to reset your password") do |format|
      format.text
      format.html { render layout: 'email' }
    end
  end

  def stolen_notification_email(stolen_notification)  
    @stolen_notification = stolen_notification
    mail(to: "#{@stolen_notification.receiver_email}, bryan@bikeindex.org", from: "bryan@bikeindex.org", subject: @stolen_notification.display_subject) do |format|
      format.text
      format.html { render layout: 'email'}
    end
    dates = stolen_notification.send_dates || []
    dates = JSON.parse(dates) unless dates.is_a?(Array)
    dates << Time.now.to_i
    stolen_notification.update_attribute :send_dates, dates.to_json
  end

  def additional_email_confirmation(user_email)
    @user_email = user_email
    @user = @user_email.user
    mail(to: "#{@user_email.email}", from: "seth@bikeindex.org", subject: 'Confirm your additional email') do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end
end