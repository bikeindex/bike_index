# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messages::ForSaleItem::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {result_view:, vehicle:, vehicle_id:, current_user:} }
  let(:current_user) { nil }
  let(:vehicle) { FactoryBot.build(:bike, id: 42) }
  let(:result_view) { nil }
  let(:search_kind) { :registration }
  let(:vehicle_id) { nil }

  it "renders" do
    expect(component).to be_present
    expect(component.css("ul")).to be_present
    expect(component.css("li")).to be_present
    expect(component.css("a").first["href"]).to match("/bikes/42")
  end

  context "result_view thumbnail" do
    it "renders" do
      expect(component).to be_present
      expect(component.css("ul")).to be_present
      expect(component.css("li")).to be_present
      expect(component.css("a").first["href"]).to match("/bikes/42")
    end
  end

  context "deleted bike" do
    let(:vehicle) { nil }
    let(:vehicle_deleted) { FactoryBot.create(:bike, deleted_at: Time.current - 1.day) }
    let(:vehicle_id) { vehicle_deleted.id }
    it "renders" do
      expect(component).to be_present
      expect(component.css("ul")).to be_present
      expect(component.css("li")).to be_present
      expect(component.css("a").first["href"]).to match("/bikes/#{vehicle_id}")
      expect(component).to have_text "Deleted"
    end
  end
end
