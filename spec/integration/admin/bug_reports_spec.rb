# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin bug reports", :js, type: :system do
  let(:user) { FactoryBot.create(:superuser) }
  let!(:bug_report) { FactoryBot.create(:bug_report) }
  let!(:bug_report_banned) { FactoryBot.create(:bug_report, user: FactoryBot.create(:email_ban).user) }
  let(:banned_alert) { "You are messaging a banned user - they will not receive the message" }

  before do
    Organization.example # Logging in lands on the admin dashboard, which reads it from the replica
    sign_in(user)
  end

  it "emails the selected senders from the card, warning while one is email banned" do
    visit admin_bug_reports_path(search_status: "all")

    check "bug_reports_selected[#{bug_report.id}]"
    click_button "Email selected senders"
    expect(page).to have_field("Message", focused: true)
    expect(page).to have_no_content(banned_alert)

    check "bug_reports_selected[#{bug_report_banned.id}]"
    expect(page).to have_content(banned_alert)

    uncheck "bug_reports_selected[#{bug_report_banned.id}]"
    expect(page).to have_no_content(banned_alert)

    # The message is required, so sending without one stays put with the selection
    click_button "Send email"
    expect(page).to have_field("bug_reports_selected[#{bug_report.id}]", checked: true)

    fill_in "Message", with: "Fixed, thanks!"
    expect {
      click_button "Send email"
      expect(page).to have_content("Emailing 1 bug report sender")
    }.to change(Notification.bug_report_reply, :count).by 1
    expect(Notification.bug_report_reply.last).to have_attributes(notifiable: bug_report, user_id: user.id)
  end
end
