# Does not inheriting from normal base class
class DonationMailer < ActionMailer::Base
  layout false
  default content_type: "multipart/alternative",
          parts_order: ["text/calendar", "text/plain", "text/html", "text/enriched"]

  def donation_email(notification_kind, payment)
    mail(to: payment.email,
         bcc: "lily+review@bikeindex.org",
         from: '"Lily Williams" <lily@bikeindex.org>',
         subject: "Thank you for donating to Bike Index",
         template_name: notification_kind)
  end
end
