class AdminMailer < ActionMailer::Base

  default from: "contact@bikeindex.org", content_type: 'multipart/alternative', parts_order: [ "text/calendar", "text/plain", "text/html", "text/enriched" ]
  default to: 'contact@bikeindex.org'

  def feedback_notification_email(feedback)
    @feedback = feedback
    mail(
      "Reply-To" => feedback.email,

      from: feedback.email, subject: feedback.title) do |format|
        format.text
        format.html { render layout: 'email_no_border' }
      end
  end

  def no_admins_notification_email(organization)
    @organization = organization
    mail(
      "Reply-To" => 'contact@bikeindex.org',

      to: 'contact@bikeindex.org', subject: "#{@organization.name} doesn't have any admins!") do |format|
        format.text
        format.html { render layout: 'email_no_border' }
      end
  end

  def invoice_error_notification_email(organization)
    @organization = organization
    mail(
      "Reply-To" => 'contact@bikeindex.org',

      to: 'contact@bikeindex.org', subject: "error with #{@organization.name} invoice") do |format|
        format.text
        format.html { render layout: 'email_no_border' }
      end
  end

  def blocked_stolen_notification_email(stolen_notification)
    @stolen_notification = stolen_notification
    mail(to: "bryan@bikeindex.org", bcc: 'contact@bikeindex.org', subject: "Stolen notification blocked!") do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

  def lightspeed_notification_email(organization, api_key)
    @organization = organization
    @api_key = api_key
    mail(to: "admin@bikeindex.org", subject: "Api Notification sent!") do |format|
      format.text
      format.html { render layout: 'email'}
    end
  end

end