require "rails_helper"

RSpec.describe Organized::MessagesController, type: :request do
  let(:organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: %w[messages geolocated_messages]) }
  let(:base_url) { "/o/#{organization.to_param}/messages" }

  include_context :request_spec_logged_in_as_user

  describe "messages root" do
    let(:current_user) { FactoryBot.create(:organization_member, organization: organization) }
    it "renders" do
      get base_url, params: json_headers
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
    context "json" do
      it "returns empty" do
        get base_url, params: { format: :json }
        expect(response.status).to eq(200)
        expect(json_result).to eq("messages" => [])
        expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
        expect(response.headers["Access-Control-Request-Method"]).not_to be_present
      end
      context "with a message" do
        let!(:organization_message_1) { FactoryBot.create(:organization_message, organization: organization, kind: "geolocated", created_at: Time.current - 1.hour) }
        let(:bike) { organization_message_1.bike }
        let(:target) do
          {
            id: organization_message_1.id,
            kind: "geolocated",
            created_at: organization_message_1.created_at.to_i,
            lat: organization_message_1.latitude,
            lng: organization_message_1.longitude,
            sender_id: organization_message_1.sender_id,
            bike: {
              id: bike.id,
              title: bike.title_string,
            },
          }
        end
        it "renders json, no cors present" do
          expect(current_user.organizations.last.message_kinds).to be_present

          get base_url, params: { format: :json }

          expect(response.status).to eq(200)
          messages = json_result["messages"]
          expect(messages.count).to eq 1
          expect(messages.first).to eq target.as_json
          expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
          expect(response.headers["Access-Control-Request-Method"]).not_to be_present
        end
      end
    end
  end
end
