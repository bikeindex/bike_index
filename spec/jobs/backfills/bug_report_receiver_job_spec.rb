require "rails_helper"

RSpec.describe Backfills::BugReportReceiverJob, type: :job do
  include ActionMailbox::TestHelper

  let(:instance) { described_class.new }

  describe "perform" do
    let(:inbound_email) do
      create_inbound_email_from_mail(from: "someone@example.com", to: "Contact@bikeindex.org",
        subject: "Hi", body: "Hello")
    end
    let!(:bug_report) { FactoryBot.create(:bug_report, inbound_email:, receiver: nil) }
    let!(:bug_report_without_inbound_email) { FactoryBot.create(:bug_report, receiver: nil) }

    it "backfills the receiver from the inbound email" do
      instance.perform

      expect(bug_report.reload.receiver).to eq "contact@bikeindex.org"
      expect(bug_report_without_inbound_email.reload.receiver).to be_nil
    end
  end
end
