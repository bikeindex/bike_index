class AdminMailer < ActionMailer::Base
  default from: 'contact@bikeindex.org', content_type: 'multipart/alternative', parts_order: ['text/calendar', 'text/plain', 'text/html', 'text/enriched']
  default to: 'contact@bikeindex.org'
  layout 'email'

  def feedback_notification_email(feedback)
    @feedback = feedback
    send_to = 'contact@bikeindex.org'
    if @feedback.feedback_type.present?
      send_to += ', bryan@bikeindex.org, lily@bikeindex.org' if @feedback.feedback_type =~ /bike_recovery/
      send_to = 'bryan@bikeindex.org' if @feedback.feedback_type =~ /stolen_information/
    end
    mail('Reply-To' => feedback.email, to: send_to, subject: feedback.title)
  end

  def no_admins_notification_email(organization)
    @organization = organization
    mail(to: 'contact@bikeindex.org', subject: "#{@organization.name} doesn't have any admins!")
  end

  def blocked_stolen_notification_email(stolen_notification)
    @stolen_notification = stolen_notification
    mail(to: 'bryan@bikeindex.org', bcc: 'contact@bikeindex.org', subject: 'Stolen notification blocked!')
  end

  def lightspeed_notification_email(organization, api_key)
    @organization = organization
    @api_key = api_key
    mail(to: 'admin@bikeindex.org', subject: 'Api Notification sent!')
  end
end
