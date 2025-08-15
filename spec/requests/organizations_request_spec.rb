require "rails_helper"

base_url = "/organizations"
RSpec.describe OrganizationsController, type: :request do
  describe "new" do
    before { Country.united_states } # Read replica
    context "with out user" do
      it "renders" do
        get "#{base_url}/new"
        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
      end
    end
    context "with user" do
      include_context :request_spec_logged_in_as_user
      it "renders with revised_layout" do
        get "#{base_url}/new"
        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
      end
    end
  end

  describe "create" do
    include_context :request_spec_logged_in_as_user
    let(:location_attrs) { {street: "", city: "San Francisco", zipcode: "94119", country_id: Country.united_states.id} }
    let(:org_attrs) do
      {
        name: "a new org",
        kind: "bike_shop",
        website: "http://example.com",
        locations_attributes: {"0" => location_attrs}
      }
    end
    it "creates org, organization_role, filters approved attrs & redirect to org with current_user" do
      expect(Organization.count).to eq(0)
      post base_url, params: {organization: org_attrs}
      expect(Organization.count).to eq(1)
      organization = Organization.where(name: "a new org").first
      expect(response).to redirect_to organization_manage_path(organization_id: organization.to_param)
      expect(organization.approved).to be_truthy
      expect(organization.api_access_approved).to be_falsey
      expect(organization.auto_user_id).to eq(current_user.id)
      expect(organization.organization_roles.count).to eq(1)
      expect(organization.organization_roles.first.user_id).to eq(current_user.id)
      expect(organization.kind).to eq "bike_shop"
      expect(organization.website).to eq "http://example.com"

      expect(organization.locations.count).to eq 1
      expect(organization.locations.first).to match_hash_indifferently location_attrs
    end

    it "creates org, organization_role, filters approved attrs & redirect to org with current_user and mails" do
      Sidekiq::Testing.inline! do
        expect(Organization.count).to eq(0)
        ActionMailer::Base.deliveries = []
        post base_url, params: {organization: org_attrs.merge(kind: "property_management", approved: false, api_access_approved: true)}
        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(Organization.count).to eq(1)
        organization = Organization.where(name: "a new org").first
        expect(response).to redirect_to organization_manage_path(organization_id: organization.to_param)
        expect(organization.approved).to be_truthy
        expect(organization.api_access_approved).to be_falsey
        expect(organization.auto_user_id).to eq(current_user.id)
        expect(organization.organization_roles.count).to eq(1)
        expect(organization.organization_roles.first.user_id).to eq(current_user.id)
        expect(organization.kind).to eq "property_management"
      end
    end

    context "existing org with name" do
      let!(:organization_existing) { FactoryBot.create(:organization, name: "some name", short_name: "A NEW org", kind: :bike_advocacy) }
      let(:target_error) { "Abbreviated name already in use by another organization. If you don't think that should be the case, contact support@bikeindex.org" }
      it "creates with a different name" do
        expect(organization_existing.reload.slug).to eq "a-new-org"
        expect {
          post base_url, params: {organization: org_attrs}
        }.to_not change(Organization, :count)
        rendered_organization = assigns(:organization)
        expect(rendered_organization.errors.full_messages).to eq([target_error])
        expect(rendered_organization.name).to eq "a new org"
        expect(rendered_organization.locations.first).to be_present

        expect(organization_existing.reload.slug).to eq "a-new-org"
        expect(organization_existing.name).to eq "some name"
        expect(organization_existing.short_name).to eq "A NEW org"
      end
    end

    it "Doesn't xss" do
      expect(Organization.count).to eq(0)
      post base_url, params: {
        organization: org_attrs.merge(name: "<script>alert(document.cookie)</script>",
          website: "<script>alert(document.cookie)</script>",
          kind: "cooooooolll_software")
      }
      expect(Organization.count).to eq(1)
      current_user.reload
      expect(current_user.organizations.count).to eq 1
      organization = Organization.last
      expect(organization.name).not_to eq("<script>alert(document.cookie)</script>")
      expect(organization.website).not_to eq("<script>alert(document.cookie)</script>")
      expect(organization.kind).to eq "other"
    end

    context "privileged kinds" do
      Organization.admin_required_kinds.each do |kind|
        it "prevents creating privileged #{kind}" do
          post base_url, params: {organization: org_attrs.merge(kind: kind)}

          expect(Organization.count).to eq(1)
          expect(Organization.last.kind).to eq("other")
        end
      end
    end
  end

  describe "legacy embeds" do
    let(:current_organization) { FactoryBot.create(:organization_with_auto_user) }

    context "non-stolen" do
      it "renders embed without xframe block" do
        get "#{base_url}/#{current_organization.slug}/embed"
        expect(response.code).to eq("200")
        expect(response).to render_template(:embed)
        expect(response.headers["X-Frame-Options"]).to be_blank
        expect(response.body).to match("<title>Register a bike with #{current_organization.short_name}</title>")
        expect(response.body).to match("Click here to register a STOLEN")
        expect(assigns(:current_user)&.id).to be_blank
        expect(assigns(:stolen)).to be_falsey
        expect(assigns(:bike).status).to eq "status_with_owner"
        expect(assigns(:organization)&.id).to eq current_organization.id
        expect(assigns(:passive_organization)&.id).to be_blank
        expect(assigns(:current_organization)&.id).to be_blank
      end
    end
    context "stolen" do
      it "renders embed without xframe block" do
        get "#{base_url}/#{current_organization.slug}/embed?stolen=1&non_stolen=true"
        expect(response.code).to eq("200")
        expect(response).to render_template(:embed)
        expect(response.headers["X-Frame-Options"]).to be_blank
        expect(response.body).to_not match("Click here to register")
        expect(assigns(:stolen)).to be_truthy
        expect(assigns(:non_stolen)).to be_falsey
        expect(assigns(:bike).status).to eq "status_stolen"
      end
    end
    context "non_stolen" do
      it "renders embed without xframe block" do
        get "#{base_url}/#{current_organization.slug}/embed?non_stolen=1"
        expect(response.code).to eq("200")
        expect(response).to render_template(:embed)
        expect(response.headers["X-Frame-Options"]).to be_blank
        expect(response.body).to_not match("Click here to register")
        expect(assigns(:stolen)).to be_falsey
        expect(assigns(:non_stolen)).to be_truthy
        expect(assigns(:bike).status).to eq "status_with_owner"
      end
    end
    context "embed_extended" do
      it "renders embed without xframe block, not stolen" do
        get "#{base_url}/#{current_organization.slug}/embed_extended?email=something@example.com"
        expect(response.code).to eq("200")
        expect(response).to render_template(:embed_extended)
        expect(response.headers["X-Frame-Options"]).to be_blank
        expect(response.body).to_not match("Click here to register")
        expect(assigns(:persist_email)).to be_truthy
        bike = assigns(:bike)
        expect(bike.status).to eq "status_with_owner"
        expect(bike.owner_email).to eq "something@example.com"
      end
    end
    context "with all the organization features possible" do
      # Because we render different fields for some of the organization features, make sure they all work
      let(:current_organization) { FactoryBot.create(:organization_with_auto_user, :organization_features, enabled_feature_slugs: OrganizationFeature::EXPECTED_SLUGS) }
      it "renders embed without xframe block" do
        get "#{base_url}/#{current_organization.slug}/embed"
        expect(response).to render_template(:embed)
        expect(response.code).to eq("200")
        expect(response.headers["X-Frame-Options"]).to be_blank
        expect(response.body).to match("Click here to register a STOLEN")
        expect(assigns(:stolen)).to be_falsey
        expect(assigns(:bike).status).to eq "status_with_owner"
        # And test rendering other things, to prove that it doesn't explode
        get "#{base_url}/#{current_organization.slug}/embed"
        expect(response.code).to eq("200")
        expect(assigns(:bike).status).to eq "status_with_owner"
        get "#{base_url}/#{current_organization.id}/embed_extended?stolen=1"
        expect(response.code).to eq("200")
        expect(response).to render_template(:embed_extended)
        expect(assigns(:bike).status).to eq "status_stolen"
      end
    end
    context "crazy b_param data" do
      let(:b_param_attrs) do
        {
          bike: {
            owner_email: "someemail@stuff.com",
            creation_organization_id: current_organization.id.to_s
          },
          stolen_record: {
            phone_no_show: "true",
            phone: "7183839292"
          }
        }
      end
      let(:b_param) { FactoryBot.create(:b_param, params: b_param_attrs) }
      it "renders" do
        expect(b_param).to be_present
        b_param.reload
        expect(b_param.status).to eq "status_stolen"
        get "#{base_url}/#{current_organization.id}/embed?b_param_id_token=#{b_param.id_token}"
        expect(response.code).to eq("200")
        expect(response).to render_template(:embed)
        expect(response.headers["X-Frame-Options"]).to be_blank
        expect(response.body).to_not match("Click here to register")
        expect(b_param.status).to eq "status_stolen"
        expect(assigns(:stolen)).to be_truthy
        bike = assigns(:bike)
        expect(bike.status).to eq "status_stolen"
        expect(bike.owner_email).to eq(b_param_attrs[:bike][:owner_email])
      end
    end
  end

  describe "lightspeed_interface" do
    context "with user with organization" do
      include_context :request_spec_logged_in_as_organization_admin
      it "redirects to posintegration" do
        get "/lightspeed_interface"
        expect(response).to redirect_to "https://posintegration.bikeindex.org?organization_id="
      end
      context "with organization_id" do
        it "redirects to posintegration" do
          get "/lightspeed_interface?organization_id=#{current_organization.id}"
          expect(response).to redirect_to "https://posintegration.bikeindex.org?organization_id=#{current_organization.id}"
        end
      end
    end
    context "with user without organization" do
      include_context :request_spec_logged_in_as_user
      it "redirects to posintegration" do
        get "/lightspeed_interface"
        expect(flash[:info]).to match(/organization/)
        expect(response).to redirect_to new_organization_path
      end
    end
    context "without user" do
      it "redirects to posintegration" do
        get "/lightspeed_interface"
        expect(response).to redirect_to new_user_path
        expect(flash[:info]).to match(/sign up/)
        expect(session[:return_to]).to eq lightspeed_interface_path
      end
    end
  end
end
