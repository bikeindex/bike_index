require "rails_helper"

RSpec.describe Admin::OrganizationsController, type: :controller do
  let(:organization) { FactoryBot.create(:organization, approved: false) }
  include_context :logged_in_as_super_admin

  describe "index" do
    it "renders" do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
    context "search" do
      let!(:organization) { FactoryBot.create(:organization, name: "Cool Bikes") }
      it "renders, finds organization" do
        get :index, search_query: "cool"
        expect(response.status).to eq 200
        expect(response).to render_template(:index)
        expect(assigns(:organizations)).to eq([organization])
      end
    end
  end

  describe "show" do
    it "renders" do
      get :show, id: organization.to_param
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
    context "unknown organization" do
      it "redirects" do
        get :show, id: "d89safdf"
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(:admin_organizations)
      end
    end
  end

  describe "edit" do
    it "renders" do
      get :edit, id: organization.to_param
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "create" do
    let(:create_attributes) do
      {
        name: "Organization name",
        short_name: "org-namo",
        previous_slug: "partied-on",
        available_invitation_count: 1200,
        website: "https://something.com",
        lock_show_on_map: true,
        show_on_map: true,
        kind: "shop",
        approved: true,
      }
    end
    context "privileged kinds" do
      Organization.admin_creatable_kinds.each do |kind|
        it "prevents creating privileged #{kind}" do
          post :create, organization: create_attributes.merge(kind: kind)
          expect(Organization.count).to eq(1)
          organization = Organization.last
          expect(organization.kind).to eq(kind)
          expect_attrs_to_match_hash(organization, create_attributes.except(:kind))
          expect(user.organizations.count).to eq 0 # it doesn't assign the user
        end
      end
    end
  end

  describe "organization update" do
    let(:state) { FactoryBot.create(:state) }
    let(:country) { state.country }
    let(:parent_organization) { FactoryBot.create(:organization) }
    let(:location1) { FactoryBot.create(:location, organization: organization, street: "old street", name: "cool name") }
    let(:update_attributes) do
      {
        name: "new name thing stuff",
        show_on_map: true,
        kind: "shop",
        parent_organization_id: parent_organization.id,
        ascend_name: "party on",
        previous_slug: "partied-on",
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
    it "updates the organization" do
      expect(location1).to be_present
      expect do
        put :update, organization_id: organization.to_param, id: organization.to_param, organization: update_attributes
      end.to change(Location, :count).by 1
      organization.reload
      expect(organization.parent_organization).to eq parent_organization
      expect(organization.name).to eq update_attributes[:name]
      expect(organization.ascend_name).to eq "party on"
      expect(organization.previous_slug).to eq "partied-on"
      # Existing location is updated
      location1.reload
      expect(location1.organization).to eq organization
      location1_update_attributes = update_attributes[:locations_attributes]["0"]
      expect_attrs_to_match_hash(location1, target_location1_hash.except(:latitude, :longitude, :organization_id, :created_at, :_destroy))

      # still existing location
      location2 = organization.locations.last
      location2_update_attributes = update_attributes[:locations_attributes][update_attributes[:locations_attributes].keys.last]
      expect_attrs_to_match_hash(location2, location2_update_attributes.except(:latitude, :longitude, :organization_id, :created_at))
    end
  end
end
