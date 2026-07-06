require "rails_helper"

RSpec.describe BugReportsMailbox do
  include ActionMailbox::TestHelper

  let(:user) { FactoryBot.create(:user_confirmed) }

  it "creates a bug report from an inbound email" do
    expect do
      receive_inbound_email_from_mail(
        from: user.email,
        to: "bugs@bikeindex.org",
        subject: "Search is broken",
        body: "I searched and nothing happened"
      )
    end.to change(BugReport, :count).by 1

    expect(BugReport.last).to have_attributes(email: user.email, user_id: user.id,
      subject: "Search is broken", body: "I searched and nothing happened")
  end

  context "with attachments" do
    let(:mail) do
      Mail.new do
        from "someone@example.com"
        to "bugs@bikeindex.org"
        subject "Broken image"
        body "See attached"
        add_file Rails.root.join("spec/fixtures/bike.jpg").to_s
      end
    end

    it "saves the attachments" do
      expect { receive_inbound_email_from_source(mail.to_s) }.to change(BugReport, :count).by 1

      bug_report = BugReport.last
      expect(bug_report).to have_attributes(email: "someone@example.com", subject: "Broken image")
      expect(bug_report.body).to match "See attached"
      expect(bug_report.attachments.count).to eq 1
      expect(bug_report.attachments.first.filename.to_s).to eq "bike.jpg"
    end
  end
end
