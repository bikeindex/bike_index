class AdminMailer < ApplicationMailer
  helper LocalizationHelper

  default content_type: "multipart/alternative",
          parts_order: ["text/calendar", "text/plain", "text/html", "text/enriched"]
  default to: "contact@bikeindex.org"

  def feedback_notification_email(feedback)
    @feedback = feedback
    send_to = "contact@bikeindex.org"
    if @feedback.feedback_type.present?
      if @feedback.feedback_type.match?(/organization_created/) || @feedback.lead_type
        send_to = "lily@bikeindex.org, craig@bikeindex.org"
      elsif @feedback.feedback_type.match?(/bike_recovery/)
        send_to += ", bryan@bikeindex.org, lily@bikeindex.org"
      elsif @feedback.feedback_type.match?(/stolen_information/)
        send_to = "bryan@bikeindex.org"
      end
    end
    mail("Reply-To" => feedback.email, :to => send_to, :subject => feedback.title)
  end

  def no_admins_notification_email(organization)
    @organization = organization
    mail(to: "contact@bikeindex.org", subject: "#{@organization.name} doesn't have any admins!")
  end

  def blocked_stolen_notification_email(stolen_notification)
    @stolen_notification = stolen_notification
    mail(to: "bryan@bikeindex.org", bcc: "contact@bikeindex.org", subject: "Stolen notification blocked!")
  end

  def unknown_organization_for_ascend_import(bulk_import)
    @bulk_import = bulk_import
    mail(to: ["lily@bikeindex.org", "craig@bikeindex.org"], subject: "Unknown organization for ascend import")
  end

  def lightspeed_notification_email(organization, api_key)
    @organization = organization
    @api_key = api_key
    mail(to: "admin@bikeindex.org", subject: "Api Notification sent!")
  end

  def theft_alert_notification(theft_alert, notification_type: :purchased)
    @theft_alert = theft_alert
    @theft_alert_plan = theft_alert.theft_alert_plan
    @creator = theft_alert.creator
    @bike = theft_alert.bike
    if notification_type == :recovered
      @recovered = true
      msg_subject = "RECOVERED Promoted Alert: #{@theft_alert.id}"
    else
      msg_subject = "Promoted Alert #{notification_type}: #{@theft_alert.id}"
    end
    @message = "#{notification_type.upcase} - a Promoted Alert bike was just #{notification_type}"

    mail(to: "stolenbikealerts@bikeindex.org", subject: msg_subject)
  end
end
