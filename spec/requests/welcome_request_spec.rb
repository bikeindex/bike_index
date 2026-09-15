require "rails_helper"

RSpec.describe WelcomeController, type: :request do
  describe "index" do
    it "renders, ignoring the requested response format" do
      get "/"
      expect(response.status).to eq(200)
      expect(response).to render_template("index")
      expect(flash).to_not be_present

      get "/", params: {format: :json}
      expect(response.status).to eq(200)
      expect(response).to render_template("index")
      expect(flash).to_not be_present
    end

    context "organization destroyed after passive_organization was set" do
      include_context :request_spec_logged_in_as_organization_admin

      it "renders" do
        get "/my_account"
        expect(session[:passive_organization_id]).to eq current_organization.id
        current_organization.destroy
        expect(Organization.unscoped.find(current_organization.id)).to be_present
        expect(current_user.reload.organizations.count).to eq 0

        get "/"
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
  end

  describe "bike_creation_graph" do
    it "renders embed without xframe block" do
      get "/bike_creation_graph"
      expect(response.code).to eq("200")
      expect(response.headers["X-Frame-Options"]).to be_blank
    end
  end

  describe "goodbye" do
    it "renders" do
      get "/goodbye"
      expect(response.status).to eq(200)
      expect(response).to render_template("goodbye")
      expect(flash).to_not be_present
    end

    context "logged_in" do
      include_context :request_spec_logged_in_as_user
      it "redirects" do
        get "/goodbye"
        expect(response).to redirect_to logout_url
      end

      context "unconfirmed user" do
        let(:current_user) { FactoryBot.create(:user) }
        it "redirects" do
          get "/goodbye"
          expect(response).to redirect_to logout_url
        end
      end
    end
  end

  describe "choose_registration" do
    it "redirects" do
      get "/choose_registration"
      expect(response).to redirect_to(new_user_url)
    end

    context "user present" do
      include_context :request_spec_logged_in_as_user
      it "renders" do
        get "/choose_registration"
        expect(response.status).to eq(200)
        expect(response).to render_template("choose_registration")
      end
    end
  end

  describe "recovery_stories" do
    let(:quote) { "I got it back <script>alert(1)</script>" }
    let!(:recovery_display) { FactoryBot.create(:recovery_display, quote:) }

    it "escapes the quote" do
      get "/recovery_stories"
      expect(response.status).to eq(200)
      expect(response.body).to_not include("<script>alert(1)</script>")
      expect(response.body).to include(ERB::Util.html_escape(quote))
    end

    context "with more stories than fit on a page" do
      let!(:recovery_displays) { FactoryBot.create_list(:recovery_display, 2) }

      it "paginates, and redirects to the last valid page when the requested one is past the end" do
        get "/recovery_stories", params: {per_page: 2}
        expect(response.status).to eq(200)
        expect(response).to render_template("recovery_stories")
        expect(assigns(:recovery_displays).count).to eq 2
        expect(flash).to_not be_present

        get "/recovery_stories", params: {per_page: 2, page: 3}
        expect(response).to redirect_to(recovery_stories_path(page: 2))
      end
    end

    context "with an organization the user has since left" do
      include_context :request_spec_logged_in_as_organization_user

      it "keeps rendering the organization as passive_organization" do
        get "/my_account"
        expect(session[:passive_organization_id]).to eq current_organization.id
        current_user.organization_roles.destroy_all

        get "/recovery_stories"
        expect(response.status).to eq(200)
        expect(response).to render_template("recovery_stories")
        expect(assigns(:recovery_displays).count).to eq 1
        # passive_organization isn't re-authorized once it's in the session
        expect(session[:passive_organization_id]).to eq current_organization.id
        expect(assigns[:passive_organization]).to eq current_organization
      end
    end
  end
end
