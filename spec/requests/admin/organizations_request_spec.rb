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
      it "raises" do
        get "#{base_url}/d89safdf"
        expect(response.status).to eq 404
      end
    end
    context "with location" do
      let!(:location) { FactoryBot.create(:location_chicago, organization: organization, name: "Main Office") }
      it "renders location with address" do
        expect(location.address_record).to be_present
        get "#{base_url}/#{organization.to_param}"
        expect(response.status).to eq(200)
        expect(response.body).to include("Main Office")
        expect(response.body).to include(location.formatted_address_string)
      end
    end
  end

  describe "edit" do
    it "renders" do
      Country.united_states # Read replica
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
            expect(organization).to match_hash_indifferently create_attributes.except(:kind)
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
    let(:location1) { FactoryBot.create(:location, organization:, name: "cool name") }
    let(:update) do
      {
        name: "new name thing stuff",
        show_on_map: true,
        kind: "shop",
        parent_organization_id: parent_organization.id,
        ascend_name: "party on",
        previous_slug: "partied-on",
        manual_pos_kind: "lightspeed_pos",
        graduated_notification_interval_days: " ",
        lightspeed_register_with_phone: "true",
        direct_unclaimed_notifications: true,
        spam_registrations: "0",
        locations_attributes: {
          "0" => {
            id: location1.id,
            name: "First shop",
            phone: "7272772727272",
            email: "stuff@goooo.com",
            publicly_visible: false,
            impound_location: true,
            default_impound_location: false,
            _destroy: 0,
            address_record_attributes: {
              postal_code: "2222222",
              city: "First city",
              region_record_id: state.id,
              country_id: country.id,
              street: "some street 2"
            }
          },
          Time.current.to_i.to_s => {
            name: "Second shop",
            phone: "7272772727272",
            email: "stuff@goooo.com",
            publicly_visible: true,
            impound_location: true,
            default_impound_location: true,
            address_record_attributes: {
              postal_code: "12243444",
              city: "cool city",
              region_record_id: state.id,
              country_id: country.id,
              street: "some street 2"
            }
          }
        }
      }
    end
    it "updates the organization" do
      expect(location1).to be_present
      Sidekiq::Job.clear_all
      expect {
        put "#{base_url}/#{organization.to_param}", params: {organization_id: organization.to_param, organization: update}
      }.to change(Location, :count).by 1
      expect(UpdateOrganizationPosKindJob.jobs.count).to eq 1
      UpdateOrganizationPosKindJob.drain # Run the jobs in the queue
      organization.reload
      expect(organization.parent_organization).to eq parent_organization
      expect(organization.name).to eq update[:name]
      expect(organization.ascend_name).to eq "party on"
      expect(organization.previous_slug).to eq "partied-on"
      expect(organization.manual_pos_kind).to eq "lightspeed_pos"
      expect(organization.pos_kind).to eq "lightspeed_pos"
      expect(organization.graduated_notification_interval).to be_blank
      expect(organization.lightspeed_register_with_phone).to be_truthy
      expect(organization.direct_unclaimed_notifications).to be_truthy
      expect(organization.spam_registrations).to be_falsey
      # Existing location is updated
      location1.reload
      expect(location1.organization).to eq organization
      expect(location1.name).to eq "First shop"
      expect(location1.phone).to eq "7272772727272"
      expect(location1.email).to eq "stuff@goooo.com"
      expect(location1.publicly_visible).to be_falsey
      expect(location1.impound_location).to be_truthy
      expect(location1.address_record).to have_attributes(street: "some street 2", city: "First city",
        postal_code: "2222222", region_record_id: state.id, country_id: country.id)

      # second location
      location2 = organization.locations.last
      expect(location2.name).to eq "Second shop"
      expect(location2.publicly_visible).to be_truthy
      expect(location2.impound_location).to be_truthy
      expect(location2.default_impound_location).to be_truthy
      expect(location2.address_record).to have_attributes(street: "some street 2", city: "cool city",
        postal_code: "12243444", region_record_id: state.id, country_id: country.id)
    end
    context "with address_record_attributes" do
      let(:location1) { FactoryBot.create(:location, organization:, name: "Original") }
      it "updates address_record via nested attributes" do
        expect(location1.address_record).to be_present
        original_address_record_id = location1.address_record.id

        put "#{base_url}/#{organization.to_param}", params: {
          organization: {
            locations_attributes: {
              "0" => {
                id: location1.id,
                address_record_attributes: {id: location1.address_record.id, street: "999 New St", city: "New City", postal_code: "99999"}
              }
            }
          }
        }

        location1.reload
        expect(location1.address_record.id).to eq original_address_record_id
        expect(location1.address_record).to have_attributes(street: "999 New St", city: "New City", postal_code: "99999")
      end
    end
    context "setting to not_set" do
      let(:organization) { FactoryBot.create(:organization, manual_pos_kind: "lightspeed_pos", lightspeed_register_with_phone: true) }
      it "updates the organization" do
        expect {
          put "#{base_url}/#{organization.to_param}", params: {organization: {manual_pos_kind: "not_set", lightspeed_register_with_phone: "0"}}
        }.to change(UpdateOrganizationPosKindJob.jobs, :count).by 1
        organization.reload
        expect(organization.manual_pos_kind).to be_blank
        expect(organization.lightspeed_register_with_phone).to be_falsey
      end
    end
    context "update manufacturer_id" do
      let(:manufacturer) { FactoryBot.create(:manufacturer) }
      it "updates" do
        put "#{base_url}/#{organization.to_param}", params: {organization: {manufacturer_id: manufacturer.id}}
        expect(organization.reload.manufacturer_id).to eq manufacturer.id
        put "#{base_url}/#{organization.to_param}", params: {organization: {manufacturer_id: ""}}
        expect(organization.reload.manufacturer_id).to be_blank
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
        organization.update(registration_field_labels: {reg_student_id: "Cool label"})
        put "#{base_url}/#{organization.to_param}", params: {organization: {graduated_notification_interval_days: "365"}}
        organization.reload
        expect(organization.graduated_notification_interval).to eq 365.days.to_i
        expect(organization.registration_field_labels).to eq({})
      end
    end
    context "updating spam_registrations" do
      it "updates" do
        put "#{base_url}/#{organization.to_param}", params: {organization: {spam_registrations: "1"}}
        organization.reload
        expect(organization.spam_registrations).to be_truthy
      end
    end
    context "updating ascend_name" do
      it "updates" do
        expect(organization.reload.ascend_name).to be_nil
        put "#{base_url}/#{organization.to_param}", params: {organization: {ascend_name: "Party name"}}
        expect(organization.reload.ascend_name).to eq "Party name"
        put "#{base_url}/#{organization.to_param}", params: {organization: {ascend_name: ""}}
        expect(organization.reload.ascend_name).to be_nil
      end
    end
    context "updating registration labels" do
      let(:target) { {reg_student_id: "party label", reg_address: "useful label", owner_email: "<p>stuff</p> again", unknown_attr: "Whoop"} }
      let(:update_params) do
        {
          :organization => {name: "new name"},
          "reg_label-reg_student_id" => "party label",
          "reg_label-reg_address" => "useful label",
          "reg_label-reg_organization_affiliation" => "  ",
          "reg_label-owner_email" => "<p>stuff</p> again ",
          "reg_label-unknown_attr" => "Whoop"

        }
      end
      it "updates the registration_field_label" do
        put "#{base_url}/#{organization.to_param}", params: update_params
        expect(organization.reload.name).to eq "new name"
        expect(organization.registration_field_labels).to eq target.as_json
      end
      context "with existing registration_field_label" do
        it "updates" do
          organization.update(registration_field_labels: {extra_registration_number: "Cool label"})
          put "#{base_url}/#{organization.to_param}", params: update_params
          organization.reload
          expect(organization.registration_field_labels).to eq target.as_json
        end
      end
    end
    context "updating with_admin_organization_attributes" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, kind: "bike_advocacy", enabled_feature_slugs: ["organization_stolen_message"]) }
      let(:organization_stolen_message) { organization.reload.organization_stolen_message }
      let(:update_params) do
        {
          name: "other namE",
          search_radius_miles: "1222.2",
          graduated_notification_interval_days: 4444,
          passwordless_user_domain: "stuff.com"
        }
      end
      it "updates the organization attributes" do
        expect(organization_stolen_message).to be_present # Because of organization feature
        expect(organization_stolen_message.kind).to eq "area"
        expect(organization_stolen_message.search_radius_miles).to eq 10.0
        put "#{base_url}/#{organization.to_param}", params: {
          organization: update_params,
          organization_stolen_message_search_radius_miles: 44,
          organization_stolen_message_kind: "association"
        }
        expect(organization.reload).to match_hash_indifferently update_params
        expect(organization_stolen_message.reload.kind).to eq "association"
        expect(organization_stolen_message.search_radius_miles).to eq 44
        # And it works with kilometers too
        put "#{base_url}/#{organization.to_param}", params: {
          organization: {search_radius_kilometers: 33},
          organization_stolen_message_search_radius_kilometers: 44,
          organization_stolen_message_kind: "area"
        }
        organization.reload
        expect(organization.reload.search_radius_kilometers).to eq 33
        expect(organization_stolen_message.reload.kind).to eq "area"
        expect(organization_stolen_message.search_radius_kilometers).to eq 44
      end
    end
    context "not updating manual_pos_kind" do
      it "updates and doesn't enqueue worker" do
        expect {
          put "#{base_url}/#{organization.to_param}", params: {organization: {name: "new name", short_name: "something else"}}
        }.to_not change(UpdateOrganizationPosKindJob.jobs, :count)
        organization.reload
        expect(organization.name).to eq "new name"
        expect(organization.short_name).to eq "something else"
        expect(organization.slug).to eq "something-else"
      end
    end
  end
end
