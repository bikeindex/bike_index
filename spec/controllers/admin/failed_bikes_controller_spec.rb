require "spec_helper"

describe Admin::FailedBikesController do
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

  describe "show" do
    it "responds with OK and renders the show template" do
      user = FactoryBot.create(:admin)
      set_current_user(user)
      b_param = BParam.create(creator_id: user.id)

      get :show, id: b_param.id

      expect(response).to be_ok
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
  end
end
