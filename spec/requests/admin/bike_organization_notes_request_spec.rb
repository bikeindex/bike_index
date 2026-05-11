# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::BikeOrganizationNotesController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:bike_organization_note) { FactoryBot.create(:bike_organization_note) }

  base_url = "/admin/bike_organization_notes"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to eq([bike_organization_note.id])
    end
  end

  describe "#show" do
    it "responds with ok" do
      get "#{base_url}/#{bike_organization_note.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
  end
end
