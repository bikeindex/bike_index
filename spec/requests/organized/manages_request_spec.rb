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

  context "logged_in_as_organization_member" do
    include_context :request_spec_logged_in_as_organization_member
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

    describe "scheduling" do
      it "redirects to the organization root path" do
        get "#{base_url}/schedule"
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe "standard organization" do
      it "does not destroy" do
        expect do
          delete "#{base_url}/#{current_organization.id}"
        end.to change(Organization, :count).by(0)
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    describe "index" do
      it "renders, sets active organization" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to eq current_organization
      end
    end

    describe "landing" do
      it "renders" do
        get "/o/#{current_organization.to_param}/landing" # Stupid different URL
        expect(response.status).to eq(200)
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to eq current_organization
      end
    end

    describe "locations" do
      it "renders" do
        get "#{base_url}/locations"
        expect(response.status).to eq(200)
        expect(response).to render_template :locations
        expect(assigns(:current_organization)).to eq current_organization
      end
    end

    describe "schedule" do
      it "redirects" do
        get "#{base_url}/schedule"
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to match "enabled"
      end
      context "appointments enabled" do
        let(:current_organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["appointments"]) }
        it "redirects" do
          get "#{base_url}/schedule"
          expect(response).to redirect_to(locations_organization_manage_path)
          expect(flash[:error]).to match "location"
        end
        context "with a location" do
          let!(:location) { FactoryBot.create(:location, organization: current_organization) }
          it "renders" do
            get "#{base_url}/schedule"
            expect(response.status).to eq(200)
            expect(response).to render_template :schedule
            expect(assigns(:current_organization)).to eq current_organization
            expect(assigns(:current_organization_location)).to eq location
          end
          context "with multiple locations" do
            let!(:location2) { FactoryBot.create(:location, organization: current_organization) }
            it "renders" do
              current_organization.reload
              expect(current_organization.default_location).to eq location
              get "#{base_url}/schedule", params: { organization_location_id: location2.id }
              expect(response.status).to eq(200)
              expect(response).to render_template :schedule
              expect(assigns(:current_organization)).to eq current_organization
              expect(assigns(:current_organization_location)).to eq location2
            end
          end
        end
      end
    end

    describe "update" do
      context "dissallowed attributes" do
        let(:org_attributes) do
          {
            available_invitation_count: 10,
            is_suspended: false,
            embedable_user_email: current_user.email,
            auto_user_id: current_user.id,
            show_on_map: false,
            api_access_approved: false,
            access_token: "stuff7",
            lock_show_on_map: true,
            is_paid: false,
          }
        end
        let(:user_2) { FactoryBot.create(:organization_member, organization: current_organization) }
        let(:update_attributes) do
          {
            # slug: 'short_name',
            slug: "cool name and stuffffff",
            available_invitation_count: "20",
            is_suspended: true,
            auto_user_id: current_user.id,
            embedable_user_email: user_2.email,
            api_access_approved: true,
            access_token: "things7",
            website: " www.drseuss.org",
            name: "some new name",
            kind: "bike_shop",
            is_paid: true,
            lock_show_on_map: false,
            show_on_map: true,
            locations_attributes: [],
          }
        end
        # Website is also permitted, but we're manually setting it
        let(:permitted_update_keys) { [:kind, :auto_user_id, :embedable_user_email, :name, :website] }
        before do
          expect(user_2).to be_present
          current_organization.update_attributes(org_attributes)
        end
        it "updates, sends message about maps" do
          put base_url, params: { organization_id: current_organization.to_param, id: current_organization.to_param, organization: update_attributes }
          expect(response).to redirect_to organization_manage_path(organization_id: current_organization.to_param)
          expect(flash[:success]).to be_present
          current_organization.reload
          # Ensure we can update what we think we can
          (permitted_update_keys - [:website, :embedable_user_email, :auto_user_id, :kind]).each do |key|
            expect(current_organization.send(key)).to eq(update_attributes[key])
          end
          # Test that the website and auto_user_id are set correctly
          expect(current_organization.auto_user_id).to eq user_2.id
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
        let(:location_1) { FactoryBot.create(:location, organization: current_organization, street: "old street", name: "cool name") }
        let(:update_attributes) do
          {
            name: current_organization.name,
            show_on_map: true,
            short_name: "Something cool",
            kind: "ambassador",
            locations_attributes: {
              "0" => {
                id: location_1.id,
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
                _destroy: 0,
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
                latitude: 22_222,
                longitude: 11_111,
                organization_id: 844,
                shown: false,
              },
            },
          }
        end
        before do
          expect(update_attributes).to be_present
          expect(current_organization.show_on_map).to be_falsey
          expect(current_organization.lock_show_on_map).to be_falsey
        end
        context "update" do
          it "updates and adds the locations and shows on map" do
            expect(current_organization.kind).to_not eq "ambassador"
            expect do
              put base_url, params: { organization_id: current_organization.to_param, id: current_organization.to_param, organization: update_attributes }
            end.to change(Location, :count).by 1
            current_organization.reload
            expect(current_organization.show_on_map).to be_truthy
            expect(current_organization.kind).to_not eq "ambassador"
            # Existing location is updated
            location_1.reload
            expect(location_1.organization).to eq current_organization
            update_attributes[:locations_attributes]["0"].except(:latitude, :longitude, :organization_id, :shown, :created_at, :_destroy).each do |k, v|
              expect(location_1.send(k)).to eq v
            end
            # ensure we are not permitting crazy assignment for first location
            update_attributes[:locations_attributes]["0"].slice(:latitude, :longitude, :organization_id, :shown).each do |k, v|
              expect(location_1.send(k)).to_not eq v
            end

            # second location
            location_2 = current_organization.locations.last
            key = update_attributes[:locations_attributes].keys.last
            update_attributes[:locations_attributes][key].except(:latitude, :longitude, :organization_id, :shown, :created_at).each do |k, v|
              expect(location_2.send(k)).to eq v
            end
            # ensure we are not permitting crazy assignment for created location
            update_attributes[:locations_attributes][key].slice(:latitude, :longitude, :organization_id, :shown).each do |k, v|
              expect(location_1.send(k)).to_not eq v
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
                  organization: { kind: "property_management", short_name: "cool short name" }
                }

            expect(assigns[:page_errors]).to be_present
            current_organization.reload
            expect(current_organization.short_name).to_not eq "cool short name"
            expect(current_organization.kind).to_not eq "property_management"
          end
        end

        context "removing a location" do
          it "removes the location" do
            update_attributes[:locations_attributes]["0"][:_destroy] = 1

            expect do
              put base_url,
                  params: {
                    organization_id: current_organization.to_param,
                    id: current_organization.to_param,
                    organization: update_attributes.merge(kind: "bike_shop", short_name: "cool other name")
                  }
            end.to change(Location, :count).by 0

            current_organization.reload
            expect(Location.where(id: location_1.id).count).to eq 0
            expect(current_organization.short_name).to eq "cool other name"
          end
        end
      end
    end

    describe "destroy" do
      context "standard organization" do
        it "destroys" do
          expect_any_instance_of(AdminNotifier).to receive(:for_organization).with(organization: current_organization, user: current_user, type: "organization_destroyed")
          expect do
            delete base_url
          end.to change(Organization, :count).by(-1)
          expect(response).to redirect_to user_root_url
          expect(flash[:info]).to be_present
        end
      end
      context "paid organization" do
        it "does not destroy" do
          current_organization.update_attribute :is_paid, true
          expect do
            delete base_url
          end.to change(Organization, :count).by(0)
          expect(response).to redirect_to organization_manage_path(organization_id: current_organization.to_param)
          expect(flash[:info]).to be_present
        end
      end
    end
  end
end
