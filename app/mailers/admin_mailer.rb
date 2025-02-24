class AdminMailer < ApplicationMailer
  helper TranslationHelper

  default content_type: "multipart/alternative",
    parts_order: ["text/calendar", "text/plain", "text/html", "text/enriched"],
    to: "contact@bikeindex.org",
    tag: "admin"

  def feedback_notification_email(feedback)
    @feedback = feedback
    send_to = "contact@bikeindex.org"
    if @feedback.feedback_type.present?
      if @feedback.feedback_type.match?(/organization_created/) || @feedback.lead_type
        send_to = "gavin@bikeindex.org, craig@bikeindex.org"
      elsif @feedback.feedback_type.match?(/bike_recovery/)
        send_to += ", bryan@bikeindex.org, gavin@bikeindex.org"
      elsif @feedback.feedback_type.match?(/stolen_information/)
        send_to = "bryan@bikeindex.org"
      end
    end
    mail("Reply-To" => feedback.email,
      :to => send_to,
      :subject => feedback.title)
  end

  def no_admins_notification_email(organization)
    @organization = organization
    mail(to: "contact@bikeindex.org",
      subject: "#{@organization.name} doesn't have any admins!")
  end

  def blocked_stolen_notification_email(stolen_notification)
    @stolen_notification = stolen_notification
    mail(to: "contact@bikeindex.org",
      subject: "Stolen notification blocked!")
  end

  def unknown_organization_for_ascend_import(notification)
    @bulk_import = notification.notifiable
    mail(to: ["gavin@bikeindex.org", "craig@bikeindex.org"],
      subject: "Unknown organization for ascend import")
  end

  def invalid_extension_for_ascend_import(notification)
    @notification = notification
    @bulk_import = notification.notifiable.bulk_imports.first
    # Notification is addressed to Gavin, but emails are hardcoded
    mail(to: ["gavin@bikeindex.org", "craig@bikeindex.org"],
      subject: "Invalid extension for ascend import")
  end

  def lightspeed_notification_email(organization, api_key)
    @organization = organization
    @api_key = api_key
    mail(to: "admin@bikeindex.org",
      subject: "API Notification sent!")
  end

  def promoted_alert_notification(promoted_alert, notification_type: nil)
    @promoted_alert = promoted_alert
    @promoted_alert_plan = promoted_alert.promoted_alert_plan
    @user = promoted_alert.user
    @bike = promoted_alert.bike
    if notification_type == "promoted_alert_recovered"
      @recovered = true
      msg_subject = "RECOVERED Promoted Alert: #{@promoted_alert.id}"
    end
    @message = "#{notification_type.upcase} - a Promoted Alert bike was just #{notification_type}"

    mail(to: "stolenbikealerts@bikeindex.org", subject: msg_subject)
  end
end
