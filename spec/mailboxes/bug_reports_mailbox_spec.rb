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
      subject: "Search is broken", body: "I searched and nothing happened",
      inbound_email_id: ActionMailbox::InboundEmail.last.id)
    expect(BugReport.last.received_at).to be_present
  end

  it "creates a bug report from an email to contact@" do
    expect do
      receive_inbound_email_from_mail(
        from: user.email,
        to: "contact@bikeindex.org",
        subject: "Question",
        body: "How do I register?"
      )
    end.to change(BugReport, :count).by 1

    expect(BugReport.last).to have_attributes(email: user.email, user_id: user.id, subject: "Question")
  end

  context "with attachments" do
    let(:mail) do
      Mail.new do
        from "Someone Reporting <someone@example.com>"
        to "bugs@bikeindex.org"
        subject "Broken image"
        body "See attached"
        add_file Rails.root.join("spec/fixtures/bike.jpg").to_s
        add_file filename: "server.log", content: "not an image"
      end
    end

    it "saves only the image attachments" do
      expect { receive_inbound_email_from_source(mail.to_s) }.to change(BugReport, :count).by 1

      bug_report = BugReport.last
      expect(bug_report).to have_attributes(email: "someone@example.com",
        from_name: "Someone Reporting", subject: "Broken image")
      expect(bug_report.body).to match "See attached"
      expect(bug_report.images.count).to eq 1
      expect(bug_report.images.first.filename.to_s).to eq "bike.jpg"
    end
  end

  context "not addressed to bugs@" do
    it "does not route to a bug report" do
      inbound_email = create_inbound_email_from_mail(
        from: user.email, to: "somewhere-else@bikeindex.org", subject: "Hi", body: "Hello"
      )
      expect { inbound_email.route }.to raise_error(ActionMailbox::Router::RoutingError)
      expect(BugReport.count).to eq 0
    end
  end
end
