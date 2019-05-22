require "spec_helper"

describe OrganizationsController do
  describe "new" do
    context "with out user" do
      it "renders" do
        get :new
        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
        expect(response).to render_with_layout("application_revised")
      end
    end
    context "with user" do
      it "renders with revised_layout" do
        set_current_user(FactoryBot.create(:user_confirmed))
        get :new
        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
        expect(response).to render_with_layout("application_revised")
      end
    end
  end

  describe "create" do
    let(:org_attrs) do
      {
        name: "a new org",
        kind: "bike_shop",
      }
    end
    it "creates org, membership, filters approved attrs & redirect to org with current_user" do
      expect(Organization.count).to eq(0)
      user = FactoryBot.create(:user_confirmed)
      set_current_user(user)
      post :create, organization: org_attrs
      expect(Organization.count).to eq(1)
      organization = Organization.where(name: "a new org").first
      expect(response).to redirect_to organization_manage_index_path(organization_id: organization.to_param)
      expect(organization.approved).to be_truthy
      expect(organization.api_access_approved).to be_falsey
      expect(organization.auto_user_id).to eq(user.id)
      expect(organization.memberships.count).to eq(1)
      expect(organization.memberships.first.user_id).to eq(user.id)
      expect(organization.kind).to eq "bike_shop"
    end

    it "creates org, membership, filters approved attrs & redirect to org with current_user and mails" do
      Sidekiq::Testing.inline! do
        expect(Organization.count).to eq(0)
        user = FactoryBot.create(:user_confirmed)
        set_current_user(user)
        ActionMailer::Base.deliveries = []
        post :create, organization: org_attrs.merge(kind: "property_management", approved: false, api_access_approved: true)
        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(Organization.count).to eq(1)
        organization = Organization.where(name: "a new org").first
        expect(response).to redirect_to organization_manage_index_path(organization_id: organization.to_param)
        expect(organization.approved).to be_truthy
        expect(organization.api_access_approved).to be_falsey
        expect(organization.auto_user_id).to eq(user.id)
        expect(organization.memberships.count).to eq(1)
        expect(organization.memberships.first.user_id).to eq(user.id)
        expect(organization.kind).to eq "property_management"
      end
    end

    it "Doesn't xss" do
      expect(Organization.count).to eq(0)
      user = FactoryBot.create(:user_confirmed)
      set_current_user(user)
      post :create, organization: org_attrs.merge(name: "<script>alert(document.cookie)</script>",
                                                  website: "<script>alert(document.cookie)</script>",
                                                  kind: "cooooooolll_software")
      expect(Organization.count).to eq(1)
      organization = Organization.last
      expect(organization.name).not_to eq("<script>alert(document.cookie)</script>")
      expect(organization.website).not_to eq("<script>alert(document.cookie)</script>")
      expect(organization.kind).to eq "other"
    end

    it "prevents creating privileged organization kinds" do
      user = FactoryBot.create(:user_confirmed)
      set_current_user(user)

      post :create, organization: org_attrs.merge(kind: "ambassador")

      expect(Organization.count).to eq(1)
      expect(Organization.last.kind).to eq("other")
    end
  end

  describe "legacy embeds" do
    let(:organization) { FactoryBot.create(:organization_with_auto_user) }

    context "non-stolen" do
      it "renders embed without xframe block" do
        get :embed, id: organization.slug
        expect(response.code).to eq("200")
        expect(response).to render_template(:embed)
        expect(response.headers["X-Frame-Options"]).not_to be_present
        expect(assigns(:stolen)).to be_falsey
        bike = assigns(:bike)
        expect(bike.stolen).to be_falsey
      end
    end
    context "stolen" do
      it "renders embed without xframe block" do
        get :embed, id: organization.slug, stolen: 1
        expect(response.code).to eq("200")
        expect(response).to render_template(:embed)
        expect(response.headers["X-Frame-Options"]).not_to be_present
        expect(assigns(:stolen)).to be_truthy
        bike = assigns(:bike)
        expect(bike.stolen).to be_truthy
      end
    end
    context "embed_extended" do
      it "renders embed without xframe block, not stolen" do
        get :embed_extended, id: organization.slug, email: "something@example.com"
        expect(response.code).to eq("200")
        expect(response).to render_template(:embed_extended)
        expect(response.headers["X-Frame-Options"]).not_to be_present
        expect(assigns(:persist_email)).to be_truthy
        bike = assigns(:bike)
        expect(bike.stolen).to be_falsey
      end
    end
    context "crazy b_param data" do
      let(:b_param_attrs) do
        {
          bike: {
            stolen: "true",
            owner_email: "someemail@stuff.com",
            creation_organization_id: organization.id.to_s,
          },
          stolen_record: {
            phone_no_show: "true",
            phone: "7183839292",
          },
        }
      end
      let(:b_param) { FactoryBot.create(:b_param, params: b_param_attrs) }
      it "renders" do
        expect(b_param).to be_present
        get :embed, id: organization.slug, b_param_id_token: b_param.id_token
        expect(response.code).to eq("200")
        expect(response).to render_template(:embed)
        expect(response.headers["X-Frame-Options"]).not_to be_present
        expect(assigns(:stolen)).to be_truthy
        bike = assigns(:bike)
        expect(bike.stolen).to be_truthy
        expect(bike.owner_email).to eq(b_param_attrs[:bike][:owner_email])
      end
    end
  end

  describe "connect_lightspeed" do
    context "with user with organization" do
      include_context :logged_in_as_organization_admin
      it "redirects to posintegration" do
        get :connect_lightspeed
        expect(response).to redirect_to "https://posintegration.bikeindex.org"
      end
    end
    context "with user without organization" do
      include_context :logged_in_as_user
      it "redirects to posintegration" do
        get :connect_lightspeed
        expect(flash[:info]).to match(/organization/)
        expect(response).to redirect_to new_organization_path
      end
    end
    context "without user" do
      it "redirects to posintegration" do
        get :connect_lightspeed
        expect(response).to redirect_to new_user_path
        expect(flash[:info]).to match(/sign up/)
        expect(session[:return_to]).to eq connect_lightspeed_path
      end
    end
  end
end
