# Does not inheriting from normal base class
class DonationMailer < ActionMailer::Base
  layout false
  default content_type: "multipart/alternative",
          parts_order: ["text/calendar", "text/plain", "text/html", "text/enriched"]
  default from: '"Lily Williams" <lily@bikeindex.org>'
  # bcc - lily+review@bikeindex.org

  def standard(payment)
    mail(to: payment.email, bcc: "lily+review@bikeindex.org", subject: "Thank you for your donation!")
  end
end
