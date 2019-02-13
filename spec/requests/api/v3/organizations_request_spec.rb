require 'spec_helper'

describe 'Organization API V3' do
  include_context :existing_doorkeeper_app

  describe 'create' do
    let(:country) { FactoryBot.create(:country, name: "United States") }
    let(:state) { FactoryBot.create(:state, name: "Oregon", abbreviation: "OR", country: country) }
    let(:token) { create_doorkeeper_token(scopes: :write_organizations) }
    let(:url) { "/api/v3/organizations?access_token=#{token.token}" }
    let(:location_1) {
      {
        name: "HQ",
        phone: "5031112222",
        street: "1111 SE Belmont Street",
        city: "Portland",
        country: state.country.name,
        state: state.name,
        zipcode: "97215"
      }
    }
    let(:location_2) {
      {
        name: "Admin",
        phone: "5033334444",
        street: "2222 SE Morrison Street",
        city: "Portland",
        state: state.name,
        country: state.country.name,
        zipcode: "97214"
      }
    }
    let(:organization_attrs) do
      {
        name: "Geoff's Bike Shop",
        kind: "bike_shop",
        website: "https://bikes.geoffereth.com",
        locations: [location_1, location_2]
      }
    end
    let(:organization_json) { organization_attrs.to_json }

    context "invalid auth" do
      describe "without access token" do
        it 'errors and returns a 401' do
          post '/api/v3/organizations', organization_json
          expect(response).to_not be_successful
          expect_status 401
        end
      end
  
      context 'without write_organizations scope' do
        let(:invalid_token) { create_doorkeeper_token(scopes: :write_bikes) }
        it "errors and returns a 403" do
          post "/api/v3/organizations?access_token=#{invalid_token.token}", organization_json, json_headers
          expect(response).to_not be_successful
          expect_status 403
        end
      end

      context "without access to the write_organizations feature" do
        it "errors and returns a 401" do
          ENV['ALLOWED_WRITE_ORGANIZATIONS'] = 'some-other-uid'
          post url, organization_json, json_headers
          expect_status 401
          expect_json(error: "Unauthorized. Cannot write organiztions")
        end
      end
    end

    describe "valid auth" do 
      before do
        ENV['ALLOWED_WRITE_ORGANIZATIONS'] = token.application.uid
      end

      it "requires organization params" do
        post url, {}, json_headers
        expect(response).to_not be_successful
        expect_status 400
        expect_json(error: "name is missing, website is missing, kind is missing, kind does not have a valid value")
      end

      it "requires a valid kind" do
        org_json = organization_attrs.merge(kind: "The best kind ever").to_json
        post url, org_json, json_headers
        expect_status 400
        expect_json(error: "kind does not have a valid value")
      end

      it "requires a valid website" do
        org_json = organization_attrs.merge(website: "funtimes://everyday.com").to_json
        post url, org_json, json_headers
        expect_status 400
        expect_json(error: "website is invalid")
      end

      it "creates a new organization with locations" do 
        post url, organization_json, json_headers
        expect(response).to be_successful
        expect_status 201
        expect_json(organization: {
          name: "Geoff's Bike Shop", 
          website: "https://bikes.geoffereth.com", 
          kind: "bike_shop", 
          locations: [ 
            { address: "1111 SE Belmont Street, Portland, OR, 97215, United States" }.merge(location_1),
            { address: "2222 SE Morrison Street, Portland, OR, 97214, United States" }.merge(location_2)
          ]
        })
      end

      context "location" do
        it "is not required" do
          post url, organization_attrs.except(:locations).to_json, json_headers
          expect(response).to be_successful
          expect_status 201
        end
        
        it "requires a valid state and country name" do
          location_attrs = location_1.merge(
            state: "The best state ever",
            country: "The best country ever"
          )
          org_json = organization_attrs.merge(locations: [location_attrs]).to_json
          post url, org_json, json_headers
          expect(response).to_not be_successful
          expect_status 400
          expect_json(error: "locations[0][state] does not have a valid value, locations[0][country] does not have a valid value")
        end

        it "requires name, street, city, state, and country" do
          org_json = organization_attrs.merge!(locations: [{foo: "bar"}]).to_json
          post url, org_json, json_headers
          expect(response).to_not be_successful
          expect_status 400
          expect_json(error: "locations[0][name] is missing, locations[0][street] is missing, locations[0][city] is missing, locations[0][state] is missing, locations[0][country] is missing")
        end

        it "does not require phone or zipcode" do
          location_attrs = location_1.except(:phone, :zipcode)
          org_json = organization_attrs.merge!(locations: [location_attrs]).to_json
          post url, org_json, json_headers
          expect(response).to be_successful
          expect_status 201
        end
      end
    end
  end
end