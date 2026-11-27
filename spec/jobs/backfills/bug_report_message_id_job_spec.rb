require "rails_helper"

RSpec.describe Backfills::BugReportMessageIdJob, type: :job do
  include ActionMailbox::TestHelper

  let(:instance) { described_class.new }

  describe "perform" do
    let(:inbound_email) do
      create_inbound_email_from_mail(from: "someone@example.com", to: "contact@bikeindex.org",
        subject: "Hi", body: "Hello")
    end
    let!(:bug_report) { FactoryBot.create(:bug_report, inbound_email:) }
    let!(:bug_report_without_inbound_email) { FactoryBot.create(:bug_report) }

    it "backfills the message_id from the inbound email" do
      instance.perform

      expect(bug_report.reload.message_id).to eq inbound_email.message_id
      expect(bug_report_without_inbound_email.reload.message_id).to be_nil
    end
  end
end
