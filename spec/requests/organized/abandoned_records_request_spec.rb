require "rails_helper"

RSpec.describe Organized::AbandonedRecordsController, type: :request do
  include_context :organization_with_geolocated_messages
  let(:base_url) { "/o/#{organization.to_param}/abandoned_records" }

  include_context :request_spec_logged_in_as_user

  describe "abandoned_records root" do
    let(:current_user) { FactoryBot.create(:organization_member, organization: organization) }
    it "renders" do
      get base_url, json_headers
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
    context "json" do
      it "returns empty" do
        get base_url, format: :json
        expect(response.status).to eq(200)
        expect(json_result).to eq("abandoned_records" => [])
        expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
        expect(response.headers["Access-Control-Request-Method"]).not_to be_present
      end
      context "with a message" do
        let!(:abandoned_record1) { FactoryBot.create(:abandoned_record_organized, organization: organization, created_at: Time.current - 1.hour) }
        let(:bike) { abandoned_record1.bike }
        let(:target) do
          {
            id: abandoned_record1.id,
            kind: "geolocated",
            created_at: abandoned_record1.created_at.to_i,
            lat: abandoned_record1.latitude,
            lng: abandoned_record1.longitude,
            sender_id: abandoned_record1.sender_id,
            bike: {
              id: bike.id,
              title: bike.title_string,
            },
          }
        end
        it "renders json, no cors present" do
          get base_url, format: :json
          expect(response.status).to eq(200)
          abandoned_records = json_result["abandoned_records"]
          expect(abandoned_records.count).to eq 1
          expect(abandoned_records.first).to eq target.as_json
          expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
          expect(response.headers["Access-Control-Request-Method"]).not_to be_present
        end
      end
    end
  end
end
