require "spec_helper"

describe Oauth::ApplicationsController do
  include_context :existing_doorkeeper_app
  describe "index" do
    it "redirects" do
      get :index
      expect(response).to redirect_to new_session_url
      expect(flash[:error]).to be_present
    end
    context "current user present" do
      include_context :logged_in_as_user
      it "renders" do
        get :index
        expect(response.status).to eq 200
        expect(response).to render_template(:index)
      end
      context "unconfirmed" do
        let!(:user) { FactoryBot.create(:user) }
        it "redirects to please_confirm_users_path" do
          expect(user.confirmed?).to be_falsey
          get :index
          expect(response).to redirect_to please_confirm_email_users_path
        end
      end
    end
  end

  describe "create" do
    include_context :logged_in_as_user
    it "creates an application and adds the v2 accessor to it" do
      v2_access_id
      app_attrs = {
        name: "Some app",
        redirect_uri: "urn:ietf:wg:oauth:2.0:oob",
      }
      post :create, doorkeeper_application: app_attrs
      app = user.oauth_applications.first
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
      it "redirects if no user present" do
        get :edit, id: doorkeeper_app.id
        expect(response).to redirect_to new_session_url
        expect(flash).to be_present
      end

      context "logged in" do
        before { set_current_user(user) } # Do separately from logged_in_as, pulling doorkeeper user
        it "renders if owned by user" do
          expect(doorkeeper_app.owner_id).to eq user.id
          get :edit, id: doorkeeper_app.id
          expect(response.code).to eq("200")
          expect(flash).not_to be_present
        end

        context "other users app" do
          let(:user) { FactoryBot.create(:user_confirmed) }
          it "redirects if not owned by user" do
            expect(doorkeeper_app.owner_id).to_not eq user.id
            get :edit, id: doorkeeper_app.id
            expect(response).to redirect_to oauth_applications_url
            expect(flash).to be_present
          end
        end

        context "admin" do
          let(:user) { FactoryBot.create(:admin) }
          it "renders if superuser" do
            expect(doorkeeper_app.owner_id).to_not eq user.id
            get :edit, id: doorkeeper_app.id
            expect(response.code).to eq("200")
            expect(flash).not_to be_present
          end
        end
      end
    end

    describe "update" do
      before { set_current_user(user) } # Do separately from logged_in_as, pulling doorkeeper user
      it "renders if owned by user" do
        expect(doorkeeper_app.owner_id).to eq user.id
        put :update, id: doorkeeper_app.id, doorkeeper_application: { name: "new thing" }
        doorkeeper_app.reload
        expect(doorkeeper_app.name).to eq("new thing")
      end

      context "other user" do
        let(:user) { FactoryBot.create(:user_confirmed) }
        it "doesn't update" do
          og_name = doorkeeper_app.name
          expect(doorkeeper_app.owner_id).to_not eq user.id
          put :update, id: doorkeeper_app.id, doorkeeper_application: { name: "new thing" }
          doorkeeper_app.reload
          expect(doorkeeper_app.name).to eq(og_name)
          expect(response).to redirect_to oauth_applications_url
        end
      end
    end
  end
end
