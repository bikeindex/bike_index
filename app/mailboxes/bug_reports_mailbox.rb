class BugReportsMailbox < ApplicationMailbox
  OUR_EMAIL_DOMAIN = "bikeindex.org"

  def process
    bug_report = BugReport.create!(
      inbound_email:,
      email: mail.from&.first,
      from_name: mail[:from]&.display_names&.first,
      receiver:,
      subject: mail.subject,
      body: body_text,
      received_at: mail.date || Time.current
    )
    mail.attachments.each do |attachment|
      next unless attachment.mime_type&.start_with?("image/")

      bug_report.images.attach(
        io: StringIO.new(attachment.decoded),
        filename: attachment.filename,
        content_type: attachment.mime_type
      )
    end
  end

  private

  # The address the sender wrote to (contact@, support@, bugs@, ...) - prefer one of ours, since a
  # report can be addressed to a mix of recipients. X-Original-To is the envelope recipient
  # Postmark's ingress prepends, the only source when we're bcc'd
  def receiver
    recipients = Array(mail.to) + Array(mail.cc)
    ([mail["X-Original-To"]&.to_s] + recipients)
      .find { it.to_s.downcase.end_with?("@#{OUR_EMAIL_DOMAIN}") } || recipients.first
  end

  def body_text
    part = mail.multipart? ? (mail.text_part || mail.html_part) : mail
    part&.decoded
  end
end
