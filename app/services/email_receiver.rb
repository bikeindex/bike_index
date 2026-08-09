# Which of our addresses an inbound email was sent to (contact@, support@, bugs@, ...)
module EmailReceiver
  extend Functionable

  OUR_EMAIL_DOMAIN = "bikeindex.org"

  # Prefer an address of ours, since a message can be addressed to a mix of recipients.
  # X-Original-To is the envelope recipient Postmark's ingress prepends, the only source
  # when we're bcc'd
  def for_mail(mail)
    recipients = Array(mail.to) + Array(mail.cc)
    address = ([mail["X-Original-To"]&.to_s] + recipients)
      .find { it.to_s.downcase.end_with?("@#{OUR_EMAIL_DOMAIN}") } || recipients.first

    EmailNormalizer.normalize(address)
  end
end
