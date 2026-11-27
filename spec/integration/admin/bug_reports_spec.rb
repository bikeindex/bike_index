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

  it "warns while a selected sender is email banned" do
    visit admin_bug_reports_path(search_status: "all")

    check "bug_reports_selected[#{bug_report.id}]"
    click_button "Email selected senders"
    expect(page).to have_field("Message")
    expect(page).to have_no_content(banned_alert)

    check "bug_reports_selected[#{bug_report_banned.id}]"
    expect(page).to have_content(banned_alert)

    uncheck "bug_reports_selected[#{bug_report_banned.id}]"
    expect(page).to have_no_content(banned_alert)
  end
end
