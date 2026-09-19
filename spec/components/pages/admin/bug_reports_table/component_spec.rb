# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::BugReportsTable::Component, type: :component do
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

  # Action View's template digest can't see the components these cell blocks render, so
  # the row key carries this component's own digest of them
  describe "row caching" do
    include_context :caching_basic

    it "keys each row to its record and this component's markup digest", :caching do
      keys = fragments_written { component }

      expect(keys.count).to eq 1
      expect(keys.first).to include(%(admin-bug-reports-#{described_class.cache_digest}), bug_report.cache_key_with_version)
    end
  end
end
