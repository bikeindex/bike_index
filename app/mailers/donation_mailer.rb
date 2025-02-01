# Does not inheriting from normal base class
class DonationMailer < ActionMailer::Base
  helper TranslationHelper
  layout false
  default content_type: "multipart/alternative",
    parts_order: ["text/calendar", "text/plain", "text/html", "text/enriched"]

  def donation_email(notification_kind, payment)
    mail(to: payment.email,
      bcc: "gavin+review@bikeindex.org",
      from: '"Gavin Hoover" <gavin@bikeindex.org>',
      subject: "Thank you for donating to Bike Index",
      template_name: notification_kind,
      tag: "donation")
  end
end
