# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketplaceListingPanel::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components//marketplace_listing_panel/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "MarketplaceListingPanel::Component"
  end
end
