# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::ResultsFrame::Component, type: :component do
  let(:options) { {frame_id: :test_results_frame, render_results:, current_path: "/search?query=x"} }
  let(:component) { render_inline(described_class.new(**options)) { "<p>the results</p>".html_safe } }

  context "with results rendered inline" do
    let(:render_results) { true }

    it "renders the block and omits the eager src" do
      expect(component).to have_css("div.search-results-frame-wrapper")
      expect(component).to have_css("turbo-frame#test_results_frame:not([src])")
      expect(component).to have_text("the results")
      expect(component).not_to have_css("[data-search-loading]")
      # overlay spinner is always present
      expect(component).to have_css(".search-loading-overlay")
    end
  end

  context "with the JS shell (results not inline)" do
    let(:render_results) { false }

    it "sets the eager src and renders the hidden spinner instead of the block" do
      expect(component).to have_css("turbo-frame#test_results_frame[src='/search?query=x']")
      expect(component).to have_css("[hidden][data-search-loading]", visible: :all)
      expect(component).not_to have_text("the results")
      expect(component).to have_css(".search-loading-overlay")
    end
  end

  # `disable_snapshot_cache: true` writes the no-cache <meta> to content_for(:header),
  # which is view-context-scoped and not observable through render_inline. It's
  # covered at the integration layer (organized/impound_records_spec).
end
