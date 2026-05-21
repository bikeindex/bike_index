require "rails_helper"

RSpec.describe BugsMailbox, type: :mailbox do
  let(:image_bytes) {
    # 1x1 PNG
    ["89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489" \
     "0000000d49444154789c63f8cfc0f01f00050001fffabcd5e60000000049454e44ae426082"].pack("H*")
  }

  def deliver(to: "bugs@bikeindex.org", from: "reporter@example.com",
    subject: "Site crash", body: "It broke", attachments: {})
    receive_inbound_email_from_mail(
      to:, from:, subject:, body:, attachments:
    )
  end

  it "files an email as a BugReport" do
    expect {
      deliver
    }.to change(BugReport, :count).by(1)

    bug_report = BugReport.last
    expect(bug_report.from_address).to eq "reporter@example.com"
    expect(bug_report.subject).to eq "Site crash"
    expect(bug_report.body).to include "It broke"
    expect(bug_report.inbound_email).to be_present
  end

  it "attaches image attachments" do
    deliver(attachments: {"screenshot.png" => image_bytes, "notes.txt" => "ignored"})

    bug_report = BugReport.last
    expect(bug_report.images.count).to eq 1
    expect(bug_report.images.first.filename.to_s).to eq "screenshot.png"
  end

  it "routes addresses matching bugs@" do
    expect {
      deliver(to: "bugs+ios@bikeindex.org")
    }.to change(BugReport, :count).by(1)
  end
end
