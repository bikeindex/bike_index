class AdminMailer < ActionMailer::Base

  default from: "administerer@bikeindex.org", :content_type => 'multipart/alternative', :parts_order => [ "text/calendar", "text/plain", "text/html", "text/enriched" ]
  default to: 'admin@bikeindex.org'

  def feedback_notification_email(feedback)
    @body = feedback.body
    @name = feedback.name
    mail(
      "Reply-To" => feedback.email,

      from: 'administerer@bikeindex.org', subject: feedback.title) do |format|
        format.text
        format.html { render layout: 'email_no_border' }
      end
  end

  def no_admins_notification_email(organization)
    @organization = organization
    mail(
      "Reply-To" => 'admin@bikeindex.org',

      to: 'admin@bikeindex.org', subject: "#{@organization.name} doesn't have any admins!") do |format|
        format.text
        format.html { render layout: 'email_no_border' }
      end
  end

  def invoice_error_notification_email(organization)
    @organization = organization
    mail(
      "Reply-To" => 'admin@bikeindex.org',

      to: 'admin@bikeindex.org', subject: "error with #{@organization.name} invoice") do |format|
        format.text
        format.html { render layout: 'email_no_border' }
      end
  end

end