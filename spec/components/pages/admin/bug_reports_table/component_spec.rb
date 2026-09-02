# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::BugReportsTable::Component, type: :component do
  it_behaves_like "cached_markup_digest"

  let(:bug_report) { FactoryBot.create(:bug_report, subject: "Broken search", body: "<p>It &amp; everything</p>") }
  let(:component) do
    with_controller_class(Admin::BugReportsController) do
      with_request_url("/admin/bug_reports") { render_inline(described_class.new(collection: [bug_report], searchable_tags: [])) }
    end
  end

  it "renders a row, with the stripped body in the tooltip" do
    expect(component).to have_css("td", text: "Broken search")
    expect(component).to have_css("td code", text: bug_report.email)
    expect(component).to have_css("[role=tooltip]", text: "It & everything", visible: :all)
  end
end
