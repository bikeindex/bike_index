require "spec_helper"

describe "Organized::MessagesController" do
  include_context :geocoder_default_location
  include_context :organization_with_geolocated_messages
  let(:base_url) { "/o/#{organization.to_param}/messages" }
  # Request specs don't have cookies so we need to stub stuff if we're in request specs
  # This is suboptimal, but hey, it gets us to request specs for now
  before { allow(User).to receive(:from_auth) { user } }

  describe "messages root" do
    let(:user) { FactoryBot.create(:organization_member, organization: organization) }
    it "renders" do
      get base_url, json_headers
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
    context "json" do
      it "returns empty" do
        get base_url, format: :json
        expect(response.status).to eq(200)
        expect(json_result).to eq("messages" => [])
        expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
        expect(response.headers["Access-Control-Request-Method"]).not_to be_present
      end
      context "with a message" do
        let!(:organization_message_1) { FactoryBot.create(:organization_message, organization: organization, kind: "geolocated", created_at: Time.now - 1.hour) }
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
          get base_url, format: :json
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
