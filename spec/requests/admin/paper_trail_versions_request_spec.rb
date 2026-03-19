# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::PaperTrailVersionsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  include_context :with_paper_trail

  base_url = "/admin/paper_trail_versions"

  describe "#index" do
    let!(:bike_organization_note) { FactoryBot.create(:bike_organization_note) }
    let(:version) { PaperTrail::Version.last }

    it "responds with ok and includes version" do
      expect(version).to be_present
      expect(version.item_type).to eq("BikeOrganizationNote")
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to include(version.id)
    end

    context "with search params" do
      it "filters by item_type and item_id" do
        get base_url, params: {search_item_type: "BikeOrganizationNote", search_item_id: bike_organization_note.id}
        expect(response.status).to eq(200)
        expect(assigns(:collection).pluck(:id)).to eq([version.id])
      end
    end
  end
end
