class CustomerMailer < ActionMailer::Base
  CONTACT_BIKEINDEX = '"Bike Index" <contact@bikeindex.org>'.freeze
  default from: CONTACT_BIKEINDEX,
          content_type: "multipart/alternative",
          parts_order: ["text/calendar", "text/plain", "text/html", "text/enriched"]
  layout "email"

  def welcome_email(user)
    @user = user

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user.email)
    end
  end

  def confirmation_email(user)
    @user = user
    @partner = @user.partner_sign_up

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user.email)
    end
  end

  def password_reset_email(user)
    @user = user
    @url = password_reset_form_users_url(token: @user.password_reset_token)

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user.email)
    end
  end

  def magic_login_link_email(user)
    @user = user
    @url = magic_link_session_url(token: @user.magic_link_token)

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user.email)
    end
  end

  def additional_email_confirmation(user_email)
    @user_email = user_email
    @user = @user_email.user

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user_email.email)
    end
  end

  def invoice_email(payment)
    @payment = payment
    @user = payment.user

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @payment.email)
    end
  end

  def stolen_bike_alert_email(customer_contact)
    @customer_contact = customer_contact
    @info = customer_contact.info_hash
    @bike = customer_contact.bike
    @bike_type = @bike.cycle_type_name&.downcase
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

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @customer_contact.user_email, subject: @customer_contact.title)
    end
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
      )
    end
  end

  def stolen_notification_email(stolen_notification)
    @stolen_notification = stolen_notification
    @user = stolen_notification.receiver

    I18n.with_locale(@user&.preferred_language) do
      mail(
        to: @stolen_notification.receiver_email,
        cc: ["bryan@bikeindex.org", "lily@bikeindex.org"],
        reply_to: @stolen_notification.sender.email,
        from: "bryan@bikeindex.org",
        subject: @stolen_notification.subject || default_i18n_subject,
      )
    end

    dates = stolen_notification.send_dates_parsed + [Time.current.to_i]
    stolen_notification.update_attribute :send_dates, dates
  end

  def bike_possibly_found_email(contact)
    @bike = contact.bike
    @user = User.fuzzy_email_find(@bike.owner_email)
    @match = contact.matching_bike

    I18n.with_locale(@user&.preferred_language || I18n.default_locale) do
      mail(to: @bike.owner_email,
           subject: "We may have found your stolen #{@bike.title_string}")
    end
  end

  def recovered_from_link(stolen_record)
    @stolen_record = stolen_record
    @bike = stolen_record.bike
    @biketype = @bike.cycle_type_name&.downcase
    @recovering_user = stolen_record.recovering_user

    I18n.with_locale(@bike.owner&.preferred_language) do
      mail(
        to: [@bike.owner_email],
        from: "bryan@bikeindex.org",
        subject: default_i18n_subject(biketype: @biketype),
      )
    end
  end

  def updated_terms_email(user)
    @user = user
    @_action_has_layout = false # layout is manually included here

    I18n.with_locale(@user&.preferred_language) do
      mail(to: @user.email, from: '"Lily Williams" <lily@bikeindex.org>')
    end
  end
end
