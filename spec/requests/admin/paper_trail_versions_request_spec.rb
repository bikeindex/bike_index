# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::PaperTrailVersionsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  base_url = "/admin/paper_trail_versions"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end

    context "with search params" do
      it "responds with ok" do
        get base_url, params: {search_item_type: "BikeOrganizationNote", search_item_id: 1}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
  end
end
