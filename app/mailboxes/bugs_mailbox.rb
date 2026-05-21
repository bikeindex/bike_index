class BugsMailbox < ApplicationMailbox
  def process
    bug_report = BugReport.create!(
      inbound_email:,
      from_address: mail.from&.first,
      from_name: mail[:from]&.display_names&.first,
      subject: mail.subject,
      body: mail_body,
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

  def mail_body
    return mail.decoded unless mail.multipart?

    (mail.text_part || mail.html_part)&.decoded
  end
end
