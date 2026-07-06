class BugReportsMailbox < ApplicationMailbox
  def process
    bug_report = BugReport.create!(
      email: mail.from&.first,
      subject: mail.subject,
      body: body_text
    )
    mail.attachments.each do |attachment|
      bug_report.attachments.attach(
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
