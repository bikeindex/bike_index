# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageSection::MarketplaceListingPanel::Component, type: :component do
  let(:options) { {marketplace_listing:} }
  let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders" do
    expect(component).to be_present
  end
end
