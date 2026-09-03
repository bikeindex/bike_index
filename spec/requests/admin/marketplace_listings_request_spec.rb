# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::MarketplaceListingsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  base_url = "/admin/marketplace_listings"

  describe "#index" do
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing) }

    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:collection).pluck(:id)).to eq([marketplace_listing.id])
    end
  end
end
