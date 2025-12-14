require "rails_helper"

base_url = "/oauth/applications"
RSpec.describe Oauth::ApplicationsController, type: :request do
  include_context :existing_doorkeeper_app
  include_context :request_spec_logged_in_as_user

  describe "index" do
    let!(:doorkeeper_app2) do
      application = Doorkeeper::Application.new(name: "MyApp", redirect_uri: "https://app.com")
      application.owner = FactoryBot.create(:user_confirmed)
      application.save
    end
    it "renders" do
      get base_url
      expect(response.status).to eq 200
      expect(response).to render_template(:index)
      expect(assigns(:applications).pluck(:id)).to eq([doorkeeper_app.id])
      get "#{base_url}?all=true"
      expect(response.status).to eq 200
      expect(response).to render_template(:index)
      expect(assigns(:applications).pluck(:id)).to eq([doorkeeper_app.id])
    end
    context "superuser" do
      it "renders, with admin" do
        get base_url
        expect(response.status).to eq 200
        expect(response).to render_template(:index)
        expect(assigns(:applications).pluck(:id)).to eq([doorkeeper_app.id])
        get "#{base_url}?all=true"
        expect(response.status).to eq 200
        expect(response).to render_template(:index)
        expect(assigns(:applications).pluck(:id)).to match_array([doorkeeper_app.id, doorkeeper_app2.id])
      end
    end
    context "no current user" do
      let(:current_user) { false }
      it "redirects" do
        get base_url
        expect(response).to redirect_to new_session_url
        expect(flash[:error]).to be_present
      end
    end
    context "unconfirmed" do
      let!(:current_user) { FactoryBot.create(:user) }
      it "redirects to please_confirm_users_path" do
        expect(current_user.confirmed?).to be_falsey
        get base_url
        expect(response).to redirect_to please_confirm_email_users_path
      end
    end
  end

  describe "create" do
    it "creates an application and adds the v2 accessor to it" do
      v2_access_id
      app_attrs = {
        name: "Some app",
        redirect_uri: "urn:ietf:wg:oauth:2.0:oob"
      }
      post base_url, params: {doorkeeper_application: app_attrs}
      app = current_user.oauth_applications.first
      expect(app.name).to eq(app_attrs[:name])
      expect(app.access_tokens.count).to eq(1)
      v2_accessor = app.access_tokens.last
      expect(v2_accessor.resource_owner_id).to eq(ENV["V2_ACCESSOR_ID"].to_i)
      expect(v2_accessor.scopes).to eq(["write_bikes"])
    end
  end

  context "existing_doorkeeper_app" do
    before { expect(doorkeeper_app).to be_present }

    describe "edit" do
      context "user's app" do
        let(:current_user) { application_owner }
        it "renders if owned by user" do
          expect(doorkeeper_app.owner_id).to eq current_user.id
          get "#{base_url}/#{doorkeeper_app.id}/edit"
          expect(response.code).to eq("200")
          expect(flash).not_to be_present
        end
      end

      context "no current user" do
        let(:current_user) { false }
        it "redirects if no user present" do
          get "#{base_url}/#{doorkeeper_app.id}/edit"
          expect(response).to redirect_to new_session_url
          expect(flash).to be_present
        end
      end

      context "other users app" do
        let(:user) { FactoryBot.create(:user_confirmed) }
        it "redirects if not owned by user" do
          expect(doorkeeper_app.owner_id).to_not eq current_user.id
          get "#{base_url}/#{doorkeeper_app.id}/edit"
          expect(response).to redirect_to oauth_applications_url
          expect(flash).to be_present
        end
      end

      context "admin" do
        let(:current_user) { FactoryBot.create(:superuser) }
        it "renders if superuser" do
          expect(doorkeeper_app.owner_id).to_not eq current_user.id
          get "#{base_url}/#{doorkeeper_app.id}/edit"
          expect(response.code).to eq("200")
          expect(flash).not_to be_present
        end
      end
    end

    describe "update" do
      context "user's app" do
        let(:current_user) { application_owner }

        it "renders if owned by user" do
          expect(doorkeeper_app.owner_id).to eq current_user.id
          put "#{base_url}/#{doorkeeper_app.id}", params: {doorkeeper_application: {name: "new thing"}}
          doorkeeper_app.reload
          expect(doorkeeper_app.name).to eq("new thing")
        end
      end

      context "other user" do
        it "doesn't update" do
          og_name = doorkeeper_app.name
          expect(doorkeeper_app.owner_id).to_not eq current_user.id
          put "#{base_url}/#{doorkeeper_app.id}", params: {doorkeeper_application: {name: "new thing"}}
          doorkeeper_app.reload
          expect(doorkeeper_app.name).to eq(og_name)
          expect(response).to redirect_to oauth_applications_url
        end
      end
    end
  end
end
