# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::SalesController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
  let(:ownership) { bike.current_ownership }
  let!(:sale) { FactoryBot.create(:sale, ownership:, seller: ownership.user) }

  base_url = "/admin/sales"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:collection).pluck(:id)).to eq([sale.id])
    end
  end

  describe "#show" do
    it "responds with ok" do
      get "#{base_url}/#{sale.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(flash).to_not be_present
    end
  end
end
