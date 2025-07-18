# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchResults::VehicleThumbnail::Component, type: :component do
  let(:options) { {bike:, current_user:, skip_cache:, search_kind:} }
  let(:skip_cache) { false }
  let(:search_kind) { :registration }
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:bike) { FactoryBot.create(:bike) }
  let(:current_user) { User.new }

  it "renders" do
    expect(component).to be_present
    expect(component).to have_content bike.mnfg_name
    expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")

    expect(component).to_not have_text(bike.serial_number.upcase)
    expect(instance.instance_variable_get(:@is_cached)).to be true
  end

  context "marketplace" do
    let(:search_kind) { :marketplace }
    let(:address_record) { FactoryBot.create(:address_record, :chicago) }
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, address_record:) }
    let(:bike) { marketplace_listing.item }

    it "renders" do
      expect(marketplace_listing.reload.for_sale?).to be_truthy
      expect(component).to be_present
      expect(component).to have_content bike.mnfg_name
      expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")

      expect(component).to_not have_text(bike.serial_number.upcase)
      expect(instance.instance_variable_get(:@is_cached)).to be true

      expect(component).to have_content marketplace_listing.amount
      expect(component).to have_content "Chicago, IL 60608"
    end
  end
end
