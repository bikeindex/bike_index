require "rails_helper"

RSpec.describe Organized::ManagesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/manage" }

  context "given an authenticated ambassador" do
    include_context :request_spec_logged_in_as_ambassador

    let(:org_root_path) { organization_root_path(organization_id: current_organization) }
    it "redirects to the organization root" do
      expect(get(base_url)).to redirect_to(org_root_path)
      expect(get("#{base_url}/locations")).to redirect_to(org_root_path)
      expect(put(base_url)).to redirect_to(org_root_path)
      expect(delete(base_url)).to redirect_to(org_root_path)
    end
  end

  context "logged_in_as_organization_user" do
    include_context :request_spec_logged_in_as_organization_user
    describe "index" do
      it "redirects to the organization root path" do
        get base_url
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe "locations" do
      it "redirects to the organization root path" do
        get "#{base_url}/locations"
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe "standard organization" do
      it "does not destroy" do
        expect {
          delete base_url
        }.to change(Organization, :count).by(0)
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    describe "show" do
      it "renders, sets active organization" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template :show
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to eq current_organization
        expect(assigns(:controller_namespace)).to eq "organized"
        expect(assigns(:page_id)).to eq "organized_manage_show"
      end
    end

    describe "landing" do
      it "renders" do
        get "/o/#{current_organization.to_param}/landing" # Stupid different URL
        expect(response.status).to eq(200)
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to eq current_organization
        expect(assigns(:page_id)).to eq "organized_manage_landing"
      end
    end

    describe "locations" do
      it "renders" do
        Country.united_states # Read replica
        get "#{base_url}/locations"
        expect(response.status).to eq(200)
        expect(response).to render_template :locations
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:page_id)).to eq "organized_manage_locations"
      end
    end

    describe "update" do
      context "dissallowed attributes" do
        let(:org_attributes) do
          {
            available_invitation_count: 10,
            embedable_user_email: current_user.email,
            auto_user_id: current_user.id,
            show_on_map: false,
            api_access_approved: false,
            approved: false,
            access_token: "stuff7",
            lock_show_on_map: true,
            is_paid: false
          }
        end
        let(:user2) { FactoryBot.create(:organization_user, organization: current_organization) }
        let(:update) do
          {
            direct_unclaimed_notifications: true,
            # slug: 'short_name',
            slug: "cool name and stuffffff",
            available_invitation_count: "20",
            auto_user_id: current_user.id,
            embedable_user_email: user2.email,
            api_access_approved: true,
            approved: true,
            access_token: "things7",
            website: " www.drseuss.org",
            name: "some new name",
            kind: "bike_shop",
            is_paid: true,
            lock_show_on_map: false,
            show_on_map: true,
            locations_attributes: []
          }
        end
        # Website is also permitted, but we're manually setting it
        let(:permitted_update_keys) { [:kind, :auto_user_id, :embedable_user_email, :name, :website, :direct_unclaimed_notifications] }
        before do
          expect(user2).to be_present
          current_organization.update(org_attributes)
        end
        it "updates, sends message about maps" do
          put base_url, params: {organization_id: current_organization.to_param, id: current_organization.to_param, organization: update}
          expect(response).to redirect_to organization_manage_path(organization_id: current_organization.to_param)
          expect(flash[:success]).to be_present
          current_organization.reload
          # Ensure we can update what we think we can (not that much)
          expect(current_organization).to match_hash_indifferently update.slice(:name, :direct_unclaimed_notifications)
          # Test that the website and auto_user_id are set correctly
          expect(current_organization.auto_user_id).to eq user2.id
          expect(current_organization.website).to eq("http://www.drseuss.org")
          # Ensure we're protecting the correct attributes
          org_attributes.except(*permitted_update_keys).each do |key, value|
            expect(current_organization.send(key)).to eq value
          end
        end
      end
      context "with locations and normal show_on_map" do
        let(:state) { FactoryBot.create(:state) }
        let(:country) { state.country }
        let(:location1) { FactoryBot.create(:location, organization: current_organization, street: "old street", name: "cool name") }
        let(:update) do
          {
            name: current_organization.name,
            show_on_map: true,
            short_name: "Something cool",
            kind: "ambassador",
            lightspeed_register_with_phone: true,
            locations_attributes: {
              "0" => {
                id: location1.id,
                name: "First shop",
                zipcode: "2222222",
                city: "First city",
                state_id: state.id,
                country_id: country.id,
                street: "some street 2",
                phone: "7272772727272",
                email: "stuff@goooo.com",
                latitude: 22_222,
                longitude: 11_111,
                organization_id: 844,
                shown: false,
                publicly_visible: "1",
                impound_location: "false",
                default_impound_location: "0",
                _destroy: 0
              },
              Time.current.to_i.to_s => {
                created_at: Time.current.to_f.to_s,
                name: "Second shop",
                zipcode: "12243444",
                city: "cool city",
                state_id: state.id,
                country_id: country.id,
                street: "some street 2",
                phone: "7272772727272",
                email: "stuff@goooo.com",
                latitude: 33_222,
                longitude: 44_111,
                organization_id: 844,
                publicly_visible: "0",
                impound_location: "true",
                default_impound_location: "0"
              }
            }
          }
        end
        before do
          expect(update).to be_present
          expect(current_organization.show_on_map).to be_falsey
          expect(current_organization.lock_show_on_map).to be_falsey
        end
        context "update" do
          it "updates and adds the locations and shows on map" do
            expect(current_organization.kind).to_not eq "ambassador"
            expect {
              put base_url, params: {organization_id: current_organization.to_param, id: current_organization.to_param, organization: update}
            }.to change(Location, :count).by 1
            current_organization.reload
            expect(current_organization.show_on_map).to be_truthy
            expect(current_organization.kind).to_not eq "ambassador"
            expect(current_organization.lightspeed_register_with_phone).to be_truthy
            # Existing location is updated
            location1.reload
            expect(location1.organization).to eq current_organization
            skipped_location_attrs = %i[latitude longitude shown organization_id created_at _destroy publicly_visible impound_location default_impound_location]
            expect(location1).to match_hash_indifferently update[:locations_attributes]["0"].except(*skipped_location_attrs)
            expect(location1.publicly_visible).to be_truthy
            expect(location1.impound_location).to be_falsey
            # ensure we are not permitting crazy assignment for first location
            update[:locations_attributes]["0"].slice(:latitude, :longitude, :organization_id, :shown).each do |k, v|
              expect(location1.send(k)).to_not eq v
            end

            # second location
            location2 = current_organization.locations.last
            key = update[:locations_attributes].keys.last
            expect(location2).to match_hash_indifferently update[:locations_attributes][key].except(*skipped_location_attrs)
            expect(location2.publicly_visible).to be_falsey
            expect(location2.impound_location).to be_truthy
            expect(location2.default_impound_location).to be_falsey
            # ensure we are not permitting crazy assignment for created location
            update[:locations_attributes][key].slice(:latitude, :longitude, :organization_id, :shown).each do |k, v|
              expect(location1.send(k)).to_not eq v
            end
          end
        end

        context "matching short_name" do
          let!(:organization2) { FactoryBot.create(:organization, short_name: "cool short name") }
          it "doesn't update" do
            put base_url,
              params: {
                organization_id: current_organization.to_param,
                id: current_organization.to_param,
                organization: {kind: "property_management", short_name: "cool short name"}
              }

            expect(assigns[:page_errors]).to be_present
            current_organization.reload
            expect(current_organization.short_name).to_not eq "cool short name"
            expect(current_organization.kind).to_not eq "property_management"
          end
        end

        context "removing a location" do
          before { update[:locations_attributes]["0"][:_destroy] = 1 }
          it "removes the location" do
            expect(location1).to be_present
            expect(current_organization.locations.count).to eq 1

            expect {
              put base_url,
                params: {
                  organization_id: current_organization.to_param,
                  id: current_organization.to_param,
                  organization: update.merge(kind: "bike_shop", short_name: "cool other name")
                }
              # Because we added 1 location and deleted 1 location
            }.to change(Location, :count).by 0

            current_organization.reload
            expect(Location.where(id: location1.id).count).to eq 0
            expect(current_organization.short_name).to eq "cool other name"

            expect(current_organization.locations.count).to eq 1
            location = current_organization.locations.first
            expect(location.name).to eq "Second shop"
            expect(location.latitude).to be_within(0.1).of(40.7)
            expect(location.longitude).to be_within(0.1).of(-74.0)
            expect(current_organization.to_coordinates).to eq location.to_coordinates
          end
          context "location is default impound location" do
            let!(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "impound_bikes") }
            let(:location1) { FactoryBot.create(:location, organization: current_organization, street: "old street", name: "cool name", impound_location: true) }
            let(:blocked_destroy_params) do
              # Only pass one location, and keep it default impound location
              update.merge(kind: "bike_shop",
                short_name: "cool other name",
                locations_attributes: {
                  "0" => update[:locations_attributes]["0"].merge(default_impound_location: "1")
                })
            end
            it "does not remove" do
              UpdateOrganizationAssociationsJob.new.perform(location1.organization_id)
              location1.reload
              expect(location1.default_impound_location?).to be_truthy
              expect(location1.destroy_forbidden?).to be_truthy
              expect(current_organization.reload.locations.count).to eq 1
              expect(current_organization.default_impound_location&.id).to eq location1.id

              expect {
                put base_url,
                  params: {
                    organization_id: current_organization.to_param,
                    id: current_organization.to_param,
                    organization: blocked_destroy_params
                  }
                current_organization.reload
              }.to raise_error(/impound/i)

              current_organization.reload
              expect(current_organization.default_impound_location&.id).to eq location1.id
              expect(Location.where(id: location1.id).count).to eq 1
            end
          end
        end

        context "only updating location" do
          let(:update) do
            {
              created_at: Time.current.to_f.to_s,
              name: "new shop",
              zipcode: "60608",
              city: "Chicago",
              state_id: state.id,
              country_id: country.id,
              street: "1300 W 14th Pl",
              phone: "7272772727272",
              email: "stuff@goooo.com",
              publicly_visible: false
            }
          end
          let(:state) { State.find_or_create_by(name: "Illinois", abbreviation: "IL", country: Country.united_states) }
          include_context :geocoder_real
          it "still updates the organization" do
            expect(current_organization.locations.count).to eq 0
            expect(current_organization.search_coordinates_set?).to be_falsey

            VCR.use_cassette("organized_manages-create-location", match_requests_on: [:path]) do
              Sidekiq::Job.clear_all
              # Need to inline to process UpdateOrganizationAssociationsJob
              Sidekiq::Testing.inline! do
                expect {
                  patch base_url,
                    params: {
                      organization_id: current_organization.to_param,
                      id: current_organization.to_param,
                      organization: {locations_attributes: {Time.current.to_i.to_s => update}}
                    }
                }.to change(Location, :count).by 1
              end
            end

            current_organization.reload
            expect(current_organization.locations.count).to eq 1
            location = current_organization.locations.first

            expect(location).to match_hash_indifferently update.except(:created_at, :organization_id)
            expect(location.latitude).to be_within(0.1).of(41.8)
            expect(location.longitude).to be_within(0.1).of(-87.6)

            expect(current_organization.to_coordinates).to eq location.to_coordinates
            expect(current_organization.search_coordinates_set?).to be_truthy
          end
        end
      end
    end

    describe "destroy" do
      context "standard organization" do
        it "destroys" do
          expect_any_instance_of(AdminNotifier).to receive(:for_organization).with(organization: current_organization, user: current_user, type: "organization_destroyed")
          expect {
            delete base_url
          }.to change(Organization, :count).by(-1)
          expect(response).to redirect_to user_root_url
          expect(flash[:info]).to be_present
        end
      end
      context "paid organization" do
        it "does not destroy" do
          current_organization.update_attribute :is_paid, true
          expect {
            delete base_url
          }.to change(Organization, :count).by(0)
          expect(response).to redirect_to organization_manage_path(organization_id: current_organization.to_param)
          expect(flash[:info]).to be_present
        end
      end
    end
  end
end
