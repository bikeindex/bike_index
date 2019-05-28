require "spec_helper"

describe Admin::AdsController, type: :controller do
  describe "index" do
    it "responds with OK and renders the index template" do
      user = FactoryBot.create(:admin)
      set_current_user(user)

      get :index

      expect(response).to be_ok
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
