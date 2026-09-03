require "rails_helper"

RSpec.describe Backfills::BugReportSenderJob, type: :job do
  include ActionMailbox::TestHelper

  let(:instance) { described_class.new }

  describe "perform" do
    let(:user) { FactoryBot.create(:user_confirmed, email: "sender@example.com") }
    let!(:membership) { FactoryBot.create(:membership, user:) }
    let(:mail) do
      Mail.new do
        from '"Bike Index" <contact@bikeindex.org>'
        reply_to "Sender Person <sender@example.com>"
        to "contact@bikeindex.org"
        subject "Bike Recovery"
        body "I got it back"
      end
    end
    let(:inbound_email) { create_inbound_email_from_source(mail.to_s) }
    let(:our_user) { FactoryBot.create(:user_confirmed, email: "contact@bikeindex.org") }
    let!(:bug_report) do
      FactoryBot.create(:bug_report, inbound_email:, email: "contact@bikeindex.org",
        from_name: "Bike Index", user_id: our_user.id)
    end

    it "re-attributes the report to the Reply-To sender, re-taking the membership snapshot" do
      expect(user.reload.member?).to be_truthy
      expect(bug_report.is_member).to be_falsey
      instance.perform

      expect(bug_report.reload).to have_attributes(email: "sender@example.com",
        from_name: "Sender Person", user_id: user.id, is_member: true)
    end

    context "with a report from outside our domain" do
      let!(:bug_report) { FactoryBot.create(:bug_report, inbound_email:, email: "someone@example.com") }

      it "leaves it alone" do
        instance.perform

        expect(bug_report.reload.email).to eq "someone@example.com"
      end
    end

    context "with the inbound email incinerated" do
      let!(:bug_report) { FactoryBot.create(:bug_report, email: "contact@bikeindex.org", inbound_email: nil) }

      it "leaves it alone" do
        instance.perform

        expect(bug_report.reload.email).to eq "contact@bikeindex.org"
      end
    end
  end
end
