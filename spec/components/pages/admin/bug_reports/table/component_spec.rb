# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::BugReports::Table::Component, type: :component do
  let(:bug_report) { FactoryBot.create(:bug_report, subject: "Broken search", body: "<p>It &amp; everything</p>") }
  let(:collection) { [bug_report] }
  let(:component) do
    with_controller_class(Admin::BugReportsController) do
      with_request_url("/admin/bug_reports") { render_inline(described_class.new(collection:, searchable_tags: [])) }
    end
  end

  it "renders a row, with the stripped body in the tooltip" do
    expect(component).to have_css("td", text: "Broken search")
    expect(component).to have_css("td code", text: bug_report.email)
    expect(component).to have_css("[role=tooltip]", text: "It & everything", visible: :all)
    expect(component).not_to have_css("input[data-email-banned]")
    expect(component).not_to have_css("td.replied_cell", text: "✓")
  end

  context "with a reply" do
    before { Notification.create!(kind: :bug_report_reply, notifiable: bug_report, message_channel_target: bug_report.email) }

    it "checks the replied column" do
      expect(component).to have_css("td.replied_cell", text: "✓")
    end
  end

  context "with an email banned sender" do
    let(:bug_report_banned) { FactoryBot.create(:bug_report, user: FactoryBot.create(:email_ban).user) }
    let(:collection) { [bug_report, bug_report_banned] }

    it "marks their checkbox, for the hidden banned alert" do
      expect(component).to have_css("input[data-email-banned]", count: 1)
      expect(component).to have_css("input[data-email-banned][value='#{bug_report_banned.id}']")
      expect(component).to have_css("[data-admin--bug-report-email-target=bannedAlert]", text: "You are messaging a banned user", visible: :all)
    end
  end

  let(:cached_record) { bug_report }
  it_behaves_like "cached_table_rows"
end
