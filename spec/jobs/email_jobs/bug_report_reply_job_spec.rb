require "rails_helper"

RSpec.describe EmailJobs::BugReportReplyJob, type: :job do
  include ActionMailbox::TestHelper

  let(:inbound_email) do
    receive_inbound_email_from_mail(from: "reporter@example.com", to: "support@bikeindex.org",
      subject: "Search is broken", body: "Nothing happened")
  end
  let(:bug_report) { BugReport.find_by(inbound_email_id: inbound_email.id) }
  let(:notification) { Notification.create!(kind: :bug_report_reply, notifiable: bug_report, user: FactoryBot.create(:superuser), message_channel_target: bug_report.email) }

  it "sends the reply threaded under the report once its inbound email is gone, and drops its BCC when it's forwarded back" do
    notification
    inbound_email.destroy!
    ActionMailer::Base.deliveries = []
    described_class.new.perform(notification.id, "Fixed it, thanks")

    mail = ActionMailer::Base.deliveries.last
    expect(mail).to have_attributes(to: ["reporter@example.com"], from: ["support@bikeindex.org"],
      reply_to: ["support@bikeindex.org"], bcc: ["support@bikeindex.org"], subject: "Re: Search is broken",
      in_reply_to: inbound_email.message_id, references: inbound_email.message_id, tag: "bug_report_reply")
    expect(mail.body.to_s).to eq "Fixed it, thanks"
    expect(notification.reload).to have_attributes(delivery_status: "delivery_success", message_id: be_present)

    expect { receive_inbound_email_from_source(mail.to_s) }.not_to change(BugReport, :count)
  end

  context "from an email banned sender" do
    let(:reporter) { FactoryBot.create(:user_confirmed, email: "reporter@example.com") }
    let(:notification) do
      Notification.create!(kind: :bug_report_reply, notifiable: bug_report, user: FactoryBot.create(:superuser), message_channel_target: bug_report.email)
    end

    it "doesn't send, banned by the reporter's ban rather than the admin's" do
      FactoryBot.create(:email_ban, user: reporter)
      expect(bug_report.user).to eq reporter
      ActionMailer::Base.deliveries = []
      described_class.new.perform(notification.id, "Fixed it, thanks")

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(notification.reload.delivery_status).to eq "delivery_banned"
    end
  end
end
