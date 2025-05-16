class CustomerMailer < ApplicationMailer
  helper TranslationHelper

  default content_type: "multipart/alternative",
    parts_order: ["text/calendar", "text/plain", "text/html", "text/enriched"]

  helper :bike

  def welcome_email(user)
    @user = user

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user.email, tag: __callee__)
    end
  end

  def confirmation_email(user)
    @user = user
    @partner = @user.partner_sign_up

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user.email, tag: __callee__)
    end
  end

  def password_reset_email(user)
    @user = user
    @url = update_password_form_with_reset_token_users_url(token: @user.token_for_password_reset)

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user.email, tag: __callee__)
    end
  end

  def magic_login_link_email(user)
    @user = user
    @url = magic_link_session_url(token: @user.magic_link_token)

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user.email, tag: __callee__)
    end
  end

  def additional_email_confirmation(user_email)
    @user_email = user_email
    @user = @user_email.user

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user_email.email, tag: __callee__)
    end
  end

  def invoice_email(payment)
    @payment = payment
    @user = payment.user

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @payment.email, tag: __callee__)
    end
  end

  def theft_survey(notification)
    mail_snippet = MailSnippet.theft_survey_2023.first
    raise "Missing theft survey mail snippet" if mail_snippet.blank?
    mail_body = mail_snippet.body.gsub("SURVEY_LINK_ID", notification.survey_id.to_s)
    if notification.user.present?
      mail_body = mail_body.gsub(/Bike Index Registrant/i, notification.user.name)
    end

    # Also replace organization if it's present
    organization = notification.bike.creation_organization
    mail_body = mail_body.gsub("a Bike Shop", organization.name) if organization.present?

    mail(to: notification.calculated_message_channel_target, from: "gavin@bikeindex.org",
      subject: mail_snippet.subject, body: mail_body + "\n\n\n\n", tag: notification.kind)
  end

  def stolen_bike_alert_email(customer_contact)
    @customer_contact = customer_contact
    @info = customer_contact.info_hash
    @bike = customer_contact.bike
    @bike_type = @bike.type
    @user = @customer_contact.user

    @location = @info["location"]
    @bike_url = "https://bikeindex.org/bikes/#{@bike.id}"
    @retweet_screen_names = @info["retweet_screen_names"]
    @twitter_account_image_url = @info["tweet_account_image"]
    @tweet_account_name = @info["tweet_account_name"]
    @tweet_account_screen_name = @info["tweet_account_screen_name"]
    @twitter_account_url = "https://twitter.com/#{@tweet_account_screen_name}"
    tweet_id = @info["tweet_id"]
    @tweet_url = "https://twitter.com/#{@tweet_account_screen_name}/status/#{tweet_id}"
    @tweet_text = @info["tweet_string"]&.split("https://bikeindex.org")&.first

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @customer_contact.user_email,
        subject: @customer_contact.title,
        tag: __callee__)
    end
  end

  def theft_alert_email(theft_alert, notification)
    @theft_alert = theft_alert
    @notification = notification
    title = if @notification.kind == "theft_alert_posted"
      "Your promoted alert advertisement is live!"
    end
    mail(to: @notification.user.email,
      subject: title,
      from: "gavin@bikeindex.org",
      tag: __callee__)
  end

  def admin_contact_stolen_email(customer_contact)
    @customer_contact = customer_contact
    @user = customer_contact.user
    @bike = @customer_contact.bike
    return if @bike.blank?

    I18n.with_locale(@user&.preferred_language) do
      mail(
        to: @customer_contact.user_email,
        sender: @customer_contact.creator_email,
        reply_to: @customer_contact.creator_email,
        subject: @customer_contact.title,
        tag: __callee__
      )
    end
  end

  def stolen_notification_email(stolen_notification)
    @stolen_notification = stolen_notification
    @user = stolen_notification.receiver

    I18n.with_locale(@user&.preferred_language) do
      mail(
        to: @stolen_notification.receiver_email,
        cc: ["bryan@bikeindex.org", "gavin@bikeindex.org"],
        reply_to: @stolen_notification.sender.email,
        from: "bryan@bikeindex.org",
        subject: @stolen_notification.subject || default_i18n_subject,
        tag: __callee__
      )
    end

    dates = stolen_notification.send_dates_parsed + [Time.current.to_i]
    stolen_notification.update_attribute :send_dates, dates
  end

  def user_alert_email(user_alert)
    @user_alert = user_alert
    @user = @user_alert.user

    I18n.with_locale(@user&.preferred_language) do
      mail(
        to: @user_alert.user.email,
        from: "bryan@bikeindex.org",
        subject: @user_alert.email_subject,
        tag: __callee__
      )
    end
  end

  def bike_possibly_found_email(contact)
    @bike = contact.bike
    @user = User.fuzzy_email_find(@bike.owner_email)
    @match = contact.matching_bike

    I18n.with_locale(@user&.preferred_language || I18n.default_locale) do
      mail(to: @bike.owner_email,
        subject: "We may have found your stolen #{@bike.title_string}",
        tag: __callee__)
    end
  end

  def recovered_from_link(stolen_record)
    @stolen_record = stolen_record
    @bike = stolen_record.bike
    @bike_type = @bike.cycle_type_name&.downcase
    @recovering_user = stolen_record.recovering_user

    I18n.with_locale(@bike.owner&.preferred_language) do
      mail(
        to: [@bike.owner_email],
        from: "bryan@bikeindex.org",
        subject: default_i18n_subject(bike_type: @bike_type),
        tag: __callee__
      )
    end
  end

  def updated_terms_email(user)
    @user = user
    @_action_has_layout = false # layout is manually included here

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user.email,
        from: '"Gavin Hoover" <gavin@bikeindex.org>',
        tag: __callee__)
    end
  end

  def marketplace_message_notification(marketplace_message)
    @marketplace_message = marketplace_message
    @user = @marketplace_message.receiver
    @marketplace_listing = @marketplace_message.marketplace_listing
    # TODO: Specific layout for these, rather than just skipping header
    @skip_header = true

    I18n.with_locale(@user&.preferred_language) do
      mail(
        to: @user.email,
        subject: @marketplace_message.subject,
        references: @marketplace_message.email_references_id,
        tag: __callee__
      )
    end
  end
end
