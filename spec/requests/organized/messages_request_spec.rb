require "spec_helper"

describe "Organized::MessagesController" do
  include_context :geocoder_default_location

  let(:organization) { FactoryGirl.create(:organization, is_paid: false, geolocated_emails: true) }
  let(:base_url) { "/o/#{organization.to_param}/messages" }

  describe "messages root" do
    context "json" do
      let(:organization_message_1) { FactoryGirl.create(:organization_message, organization: organization, kind: "geolocated", created_at: Time.now - 1.day) }
      it "renders json, no cors present" do
        get "#{base_url}"
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        pp result
        expect(response.headers['Access-Control-Allow-Origin']).not_to be_present
        expect(response.headers['Access-Control-Request-Method']).not_to be_present
      end
    end
    context "with parameters" do
      # let(:organization_message_2) { FactoryGirl.create(:organization_message, organization: organization, kind: "geolocated", created_at: Time.now - 1.hour) }
      it "returns the mates"
    end
  end
end
