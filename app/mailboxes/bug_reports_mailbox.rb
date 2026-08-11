class BugReportsMailbox < ApplicationMailbox
  def process
    email, from_name = BugReport.sender_from_mail(mail)
    bug_report = BugReport.create!(
      inbound_email:,
      email:,
      from_name:,
      receiver: BugReport.receiver_from_mail(mail),
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

  def body_text
    part = mail.multipart? ? (mail.text_part || mail.html_part) : mail
    part&.decoded
  end
end
