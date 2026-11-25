# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Search::ResultViewSelect::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {result_view:} }
  let(:result_view) { nil }

  it "renders both views, submitting the search on a change" do
    expect(component).to have_css "input[type=radio][name=search_result_view]", count: 2, visible: :all
    expect(component).to have_css "input[data-action='change->search--form#submit']", count: 2, visible: :all
    # An unrecognized result_view falls back to cards
    expect(component).to have_css "#search_result_view_cards[checked]", visible: :all
  end

  context "list" do
    let(:result_view) { :list }

    it "checks list" do
      expect(component).to have_css "#search_result_view_list[checked]", visible: :all
      expect(component).to have_no_css "#search_result_view_cards[checked]", visible: :all
    end
  end
end
