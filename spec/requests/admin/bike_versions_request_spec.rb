# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::BikeVersionsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
  let!(:bike_version) { FactoryBot.create(:bike_version, bike:, owner: bike.user) }

  base_url = "/admin/bike_versions"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:collection).pluck(:id)).to eq([bike_version.id])
    end
  end

  describe "#show" do
    it "responds with ok" do
      get "#{base_url}/#{bike_version.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(flash).to_not be_present
    end
  end
end
