# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messages::ForSaleItem::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {result_view:, vehicle:} }
  let(:vehicle) { FactoryBot.build(:bike, id: 42) }
  let(:result_view) { :thumbnail }
  let(:search_kind) { :registration }
  let(:skip_cache) { nil }
  let(:no_results) { nil }
  let(:default_no_results_text) { "No registrations exactly matched your search" }

  it "renders" do
    expect(component).to be_present
    expect(component.css("ul")).to be_present
    expect(component.css("li")).to be_present
    expect(component.css("a").first["href"]).to match("/bikes/42")
  end

  context "result_view :bike_box" do
    let(:result_view) { :bike_box }
    it "renders" do
      expect(component).to be_present
      expect(component.css("ul")).to be_present
      expect(component.css("li")).to be_present
      expect(component.css("a").first["href"]).to match("/bikes/42")
      expect(component).to_not have_text default_no_results_text
    end
  end
end
