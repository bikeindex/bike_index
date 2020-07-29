require "rails_helper"

RSpec.describe DocumentationController, type: :controller do
  describe "index" do
    it "redirects to current api documentation" do
      get :index
      expect(response).to redirect_to("/documentation/api_v3")
      expect(flash).to_not be_present
    end
  end

  describe "authorize" do
    include_context :existing_doorkeeper_app
    let!(:access_grant) { doorkeeper_app.access_grants.create!(resource_owner_id: user.id, redirect_uri: "*", expires_in: 10.minutes) }
    it "renders" do
      set_current_user(user)
      get :authorize, params: {code: access_grant.token}
      expect(assigns(:application)).to eq doorkeeper_app
      expect(response.code).to eq("200")
      expect(response).to render_template("authorize")
    end
  end

  describe "api_v2" do
    it "renders" do
      get :api_v2
      expect(response.code).to eq("200")
      expect(response).to render_template("api_v2")
      expect(flash).to_not be_present
    end
  end

  describe "api_v3" do
    it "renders" do
      get :api_v3
      expect(response.code).to eq("200")
      expect(response).to render_template("api_v3")
      expect(flash).to_not be_present
    end
  end
end
