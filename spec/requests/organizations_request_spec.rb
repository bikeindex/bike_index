require "rails_helper"

base_url = "/organizations"
RSpec.describe OrganizationsController, type: :request do
  describe "new" do
    it "redirects to the signup flow" do
      get "#{base_url}/new"
      expect(response).to redirect_to new_organization_signup_path
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
        # The photo uploads straight to storage, scoped by the registration's own token
        expect(response.body).to include "bike[image_signed_id]"
        expect(response.body).to include "/register/direct_uploads?b_param_token=#{assigns(:b_param).id_token}"
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
      context "with an invalid enum value" do
        let(:b_param_attrs) do
          {bike: {owner_email: "someemail@stuff.com", frame_material: "1",
                  creation_organization_id: current_organization.id.to_s}}
        end
        it "renders" do
          get "#{base_url}/#{current_organization.id}/embed_extended?b_param_id_token=#{b_param.id_token}"
          expect(response.code).to eq("200")
          expect(response).to render_template(:embed_extended)
          expect(assigns(:bike).frame_material).to be_blank
        end
      end
    end
  end

  describe "qr" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:target_url) { "http://www.example.com/register/new?organization_id=#{organization.slug}" }

    it "renders a png, linking to the registration page" do
      get "#{base_url}/#{organization.slug}/qr"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq "image/png"
      expect(assigns(:organization)).to eq organization
      expect(assigns(:qr_url)).to eq target_url

      get "#{base_url}/#{organization.slug}/qr.png"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq "image/png"
      expect(assigns(:qr_url)).to eq target_url
    end

    context "target=shop_display" do
      let(:target_url) { "http://www.example.com/organizations/#{organization.slug}/embed?non_stolen=true&shop_display=true" }

      it "links to the embed" do
        get "#{base_url}/#{organization.slug}/qr?target=shop_display"
        expect(response.status).to eq(200)
        expect(assigns(:qr_url)).to eq target_url
      end
    end

    context "target=landing" do
      let(:target_url) { "http://www.example.com/#{organization.slug}" }

      it "links to the landing page, even without a landing page route" do
        expect(LandingPageOrganizations::SLUGS).to_not include(organization.slug)

        get "#{base_url}/#{organization.slug}/qr?target=landing"
        expect(response.status).to eq(200)
        expect(assigns(:qr_url)).to eq target_url
      end
    end

    context "unknown target" do
      it "links to the registration page" do
        get "#{base_url}/#{organization.slug}/qr?target=xxxxx"
        expect(response.status).to eq(200)
        expect(assigns(:qr_url)).to eq target_url
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
      it "redirects to the signup flow" do
        get "/lightspeed_interface"
        expect(flash[:notice]).to match(/organization/)
        expect(response).to redirect_to new_organization_signup_path
        expect(session[:return_to]).to eq lightspeed_interface_path
      end
    end
    context "without user" do
      it "redirects to the signup flow, which makes the account too" do
        get "/lightspeed_interface"
        expect(response).to redirect_to new_organization_signup_path
        expect(flash[:notice]).to match(/organization/)
        expect(session[:return_to]).to eq lightspeed_interface_path
      end
    end
  end
end
