# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::MarketplaceMessagesController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:marketplace_message) { FactoryBot.create(:marketplace_message) }

  base_url = "/admin/marketplace_messages"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:collection).pluck(:id)).to eq([marketplace_message.id])
    end

    context "sorted by listing amount" do
      let!(:marketplace_message_pricier) do
        FactoryBot.create(:marketplace_message, marketplace_listing: FactoryBot.create(:marketplace_listing, :for_sale, amount_cents: 9_000))
      end

      it "orders by the listing's amount" do
        get base_url, params: {sort: "amount_cents", direction: "asc"}
        expect(response.status).to eq(200)
        expect(assigns(:collection).pluck(:id)).to eq([marketplace_message.id, marketplace_message_pricier.id])

        get base_url, params: {sort: "amount_cents", direction: "desc", search_bike_id: marketplace_message_pricier.item.id}
        expect(response.status).to eq(200)
        expect(assigns(:collection).pluck(:id)).to eq([marketplace_message_pricier.id])
      end
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
