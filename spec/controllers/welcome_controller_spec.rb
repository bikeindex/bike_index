require "rails_helper"

RSpec.describe WelcomeController, type: :controller do
  describe "index" do
    it "renders" do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template("index")
      expect(flash).to_not be_present
    end
    context "json request format" do
      it "renders revised_layout (ignoring response format)" do
        get :index, params: {format: :json}
        expect(response.status).to eq(200)
        expect(response).to render_template("index")
        expect(flash).to_not be_present
      end
    end
    context "organization deleted" do
      include_context :logged_in_as_organization_admin
      it "renders" do
        org_id = organization.id
        session[:passive_organization_id] = org_id
        expect(user.default_organization).to be_present
        organization.destroy
        user.reload
        expect(Organization.unscoped.find(org_id)).to be_present
        expect(user.organizations.count).to eq 0
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
  end

  describe "bike_creation_graph" do
    it "renders embed without xframe block" do
      get :bike_creation_graph
      expect(response.code).to eq("200")
      expect(response.headers["X-Frame-Options"]).to eq "None"
    end
  end

  describe "goodbye" do
    it "renders" do
      get :goodbye
      expect(response.status).to eq(200)
      expect(response).to render_template("goodbye")
      expect(flash).to_not be_present
    end
    context "logged_in" do
      include_context :logged_in_as_user
      it "redirects" do
        get :goodbye
        expect(response).to redirect_to logout_url
      end
      context "unconfirmed user" do
        let(:user) { FactoryBot.create(:user) }
        it "redirects" do
          get :goodbye
          expect(response).to redirect_to logout_url
        end
      end
    end
  end

  describe "choose registration" do
    context "user not present" do
      it "redirects" do
        get :choose_registration
        expect(response).to redirect_to(new_user_url)
      end
    end
    context "user present" do
      it "renders" do
        user = FactoryBot.create(:user_confirmed)
        set_current_user(user)
        get :choose_registration
        expect(response.status).to eq(200)
        expect(response).to render_template("choose_registration")
      end
    end
  end

  describe "recovery_stories" do
    it "renders recovery stories" do
      FactoryBot.create_list(:recovery_display, 3)
      get :recovery_stories, params: {per_page: 2}
      expect(assigns(:recovery_displays).count).to eq 2
      expect(response.status).to eq(200)
      expect(response).to render_template("recovery_stories")
      expect(flash).to_not be_present
    end

    it "renders no recovery stories if requested page exceeds valid range" do
      FactoryBot.create_list(:recovery_display, 2)
      get :recovery_stories, params: {per_page: 2, page: 2}
      expect(assigns(:recovery_displays)).to be_empty
      expect(response.status).to eq(200)
      expect(response).to render_template("recovery_stories")
      expect(flash).to be_present
    end
    context "with user" do
      include_context :logged_in_as_user
      let(:organization) { FactoryBot.create(:organization) }
      it "renders" do
        session[:passive_organization_id] = organization.id # Even though the user isn't part of the organization, permit it
        FactoryBot.create_list(:recovery_display, 2)
        get :recovery_stories
        expect(assigns(:recovery_displays).count).to eq 2
        expect(response.status).to eq(200)
        expect(response).to render_template("recovery_stories")
        # These tests use to be in user_home, but that switched to be a request spec, so these moved here
        expect(session[:passive_organization_id]).to eq organization.id
        expect(assigns[:passive_organization]).to eq organization
      end
    end
  end
end
