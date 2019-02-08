require 'spec_helper'

describe 'Organization API V3' do
  let(:organizations) { create(:organization) }
  include_context :existing_doorkeeper_app

  describe 'create' do
    let(:organization_params) do
      {
        name: "Geoff's Bike Shop",
        kind: "bike_shop",
        website: "https://geoffereth.com",
        location: {
          street: "111 Bath Street",
          city: "Santa Barbara",
          state: "California",
          country: "United States",
          zipcode: "93101"
        }
      }.to_json
    end

    context "invalid auth" do
      describe "without access token" do
        it 'errors and returns a 401' do
          post '/api/v3/organizations', organization_params
          expect(response).to_not be_successful
          expect_status 401
        end
      end
  
      context 'without write_organizations scope' do
        let(:invalid_token) { create_doorkeeper_token(scopes: :write_bikes) }
        it "errors and returns a 403" do
          post "/api/v3/organizations?access_token=#{invalid_token.token}", organization_params, json_headers
          expect(response).to_not be_successful
          expect_status 403
        end
      end
    end

    context "valid auth" do 
      let(:token) { create_doorkeeper_token(scopes: :write_organizations) }

      it "creates a new organization with one location" do 
        post "/api/v3/organizations?access_token=#{token.token}", organization_params, json_headers
        expect(response).to be_successful
        # ... expect(response.body).to eq("foo")
      end
    end
  end
end