# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::SearchResults::Container::Component, type: :component do
  let(:component) { render_inline(described_class.new(bikes:, no_results:, result_view:)) }
  let(:bikes) { [FactoryBot.create(:bike, id: 42)] }
  let(:result_view) { nil }
  let(:no_results) { "No Listings exactly matched your search" }

  it "renders the cards, in the cards grid" do
    expect(component.css("ul").first["class"]).to match("grid-cols-")
    expect(component.css("li").count).to eq 1
    expect(component).to_not have_text no_results
  end

  context "result_view :list" do
    let(:result_view) { :list }

    it "renders the rows, in the list's container query" do
      expect(component.css("ul").first["class"]).to match("tw:@container")
    end
  end

  context "no bikes" do
    let(:bikes) { [] }

    it "renders no_results in place of the list" do
      expect(component.css("ul")).to_not be_present
      expect(component).to have_text no_results
    end
  end
end
