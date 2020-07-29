require "rails_helper"

base_url = "/admin/organizations"
RSpec.describe Admin::OrganizationsController, type: :request do
  let(:organization) { FactoryBot.create(:organization, approved: false) }
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template("admin/organizations/index")
    end
    context "search" do
      let!(:organization) { FactoryBot.create(:organization, name: "Cool Bikes") }
      it "renders, finds organization" do
        get base_url, params: {search_query: "cool"}
        expect(response.status).to eq 200
        expect(response).to render_template("admin/organizations/index")
        expect(assigns(:organizations)).to eq([organization])
      end
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{organization.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template("admin/organizations/show")
    end
    context "unknown organization" do
      it "redirects" do
        get "#{base_url}/d89safdf"
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(:admin_organizations)
      end
    end
  end

  describe "edit" do
    it "renders" do
      get "#{base_url}/#{organization.to_param}/edit"
      expect(response.status).to eq(200)
      expect(response).to render_template("admin/organizations/edit")
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
        approved: true
      }
    end
    context "privileged kinds" do
      Organization.admin_required_kinds.each do |kind|
        it "prevents creating privileged #{kind}" do
          post base_url, params: {organization: create_attributes.merge(kind: kind)}
          expect(Organization.count).to eq(1)
          organization = Organization.last
          expect(organization.kind).to eq(kind)
          unless organization.ambassador? # Ambassadors have special attrs set
            expect_attrs_to_match_hash(organization, create_attributes.except(:kind))
          end
          expect(current_user.organizations.count).to eq 0 # it doesn't assign the user
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
        manual_pos_kind: "lightspeed_pos",
        graduated_notification_interval_days: " ",
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
            publicly_visible: false,
            impound_location: true,
            default_impound_location: false,
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
            latitude: 22_222,
            longitude: 11_111,
            organization_id: 844,
            shown: false,
            publicly_visible: true,
            impound_location: true,
            default_impound_location: true
          }
        }
      }
    end
    it "updates the organization" do
      expect(location1).to be_present
      Sidekiq::Worker.clear_all
      expect {
        put "#{base_url}/#{organization.to_param}", params: {organization_id: organization.to_param, organization: update_attributes}
      }.to change(Location, :count).by 1
      expect(UpdateOrganizationPosKindWorker.jobs.count).to eq 1
      UpdateOrganizationPosKindWorker.drain # Run the jobs in the queue
      organization.reload
      expect(organization.parent_organization).to eq parent_organization
      expect(organization.name).to eq update_attributes[:name]
      expect(organization.ascend_name).to eq "party on"
      expect(organization.previous_slug).to eq "partied-on"
      expect(organization.manual_pos_kind).to eq "lightspeed_pos"
      expect(organization.pos_kind).to eq "lightspeed_pos"
      expect(organization.graduated_notification_interval).to be_blank
      # Existing location is updated
      location1.reload
      expect(location1.organization).to eq organization
      location1_update_attributes = update_attributes[:locations_attributes]["0"]
      expect_attrs_to_match_hash(location1, location1_update_attributes.except(:latitude, :longitude, :organization_id, :created_at, :_destroy))

      # still existing location
      location2 = organization.locations.last
      location2_update_attributes = update_attributes[:locations_attributes][update_attributes[:locations_attributes].keys.last]
      expect_attrs_to_match_hash(location2, location2_update_attributes.except(:latitude, :longitude, :organization_id, :created_at))
    end
    context "setting to not_set" do
      let(:organization) { FactoryBot.create(:organization, manual_pos_kind: "lightspeed_pos") }
      it "updates the organization" do
        expect {
          put "#{base_url}/#{organization.to_param}", params: {organization: {manual_pos_kind: "not_set"}}
        }.to change(UpdateOrganizationPosKindWorker.jobs, :count).by 1
        organization.reload
        expect(organization.manual_pos_kind).to be_blank
      end
    end
    context "update passwordless_user_domain" do
      it "updates (only blocking non-developers in frontend because whateves)" do
        put "#{base_url}/#{organization.to_param}", params: {organization: {passwordless_user_domain: "@bikeindex.org"}}
        organization.reload
        expect(organization.passwordless_user_domain).to eq "@bikeindex.org"
      end
    end
    context "updating graduated notifications" do
      it "updates graduated_notification_interval_days" do
        put "#{base_url}/#{organization.to_param}", params: {organization: {graduated_notification_interval_days: "365"}}
        organization.reload
        expect(organization.graduated_notification_interval).to eq 365.days.to_i
      end
    end
    context "not updating manual_pos_kind" do
      it "updates and doesn't enqueue worker" do
        expect {
          put "#{base_url}/#{organization.to_param}", params: {organization: {name: "new name", short_name: "something else"}}
        }.to_not change(UpdateOrganizationPosKindWorker.jobs, :count)
        organization.reload
        expect(organization.name).to eq "new name"
        expect(organization.short_name).to eq "something else"
        expect(organization.slug).to eq "something-else"
      end
    end
  end
end
