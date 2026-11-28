class BugReportsMailbox < ApplicationMailbox
  # On our replies to a report, whose BCC to the inbox is forwarded back here
  REPLY_HEADER = "X-Bike-Index-Bug-Report-Reply"

  def process
    return if mail.header[REPLY_HEADER].present?

    email, from_name = BugReport.sender_from_mail(mail)
    body = body_text
    bug_report = BugReport.create!(
      inbound_email:,
      message_id: mail.message_id,
      email:,
      from_name:,
      receiver: BugReport.receiver_from_mail(mail),
      subject: mail.subject,
      body:,
      tags: BugReport.tags_from_mail(mail, body),
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

  def body_text
    part = mail.multipart? ? (mail.text_part || mail.html_part) : mail
    part&.decoded
  end
end
