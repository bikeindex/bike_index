class AdminMailer < ActionMailer::Base
  default from: 'contact@bikeindex.org', content_type: 'multipart/alternative', parts_order: ['text/calendar', 'text/plain', 'text/html', 'text/enriched']
  default to: 'contact@bikeindex.org'

  def feedback_notification_email(feedback)
    @feedback = feedback
    send_to = 'contact@bikeindex.org'
    if @feedback.feedback_type.present?
      send_to += ', bryan@bikeindex.org' if @feedback.feedback_type =~ /bike_recovery/
      send_to = 'bryan@bikeindex.org' if @feedback.feedback_type =~ /stolen_information/
    end
    mail('Reply-To' => feedback.email, to: send_to, subject: feedback.title) do |format|
      format.text
      format.html { render layout: 'email_no_border' }
    end
  end

  def no_admins_notification_email(organization)
    @organization = organization
    mail(
      to: 'contact@bikeindex.org', subject: "#{@organization.name} doesn't have any admins!") do |format|
        format.text
        format.html { render layout: 'email_no_border' }
      end
  end

  def invoice_error_notification_email(organization)
    @organization = organization
    mail(
      to: 'contact@bikeindex.org', subject: "error with #{@organization.name} invoice") do |format|
        format.text
        format.html { render layout: 'email_no_border' }
      end
  end

  def blocked_stolenNotification_email(stolenNotification)
    @stolenNotification = stolenNotification
    mail(to: 'bryan@bikeindex.org', bcc: 'contact@bikeindex.org', subject: 'Stolen notification blocked!') do |format|
      format.text
      format.html { render layout: 'email' }
    end
  end

  def lightspeed_notification_email(organization, api_key)
    @organization = organization
    @api_key = api_key
    mail(to: 'admin@bikeindex.org', subject: 'Api Notification sent!') do |format|
      format.text
      format.html { render layout: 'email' }
    end
  end
end
