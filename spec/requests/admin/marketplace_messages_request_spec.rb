# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::MarketplaceMessagesController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:marketplace_messages) { FactoryBot.create(:marketplace_message) }

  base_url = "/admin/marketplace_messages"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:collection).pluck(:id)).to eq([marketplace_listing.id])
    end
  end

  describe "#show" do
    it "responds with ok" do
      get "#{base_url}/#{marketplace_message.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(flash).to_not be_present
    end
  end
end
