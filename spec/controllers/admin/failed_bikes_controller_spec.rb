require "spec_helper"

describe Admin::FailedBikesController do
  describe "index" do
    before do
      user = FactoryBot.create(:admin)
      set_current_user(user)
      get :index
    end
  end

  describe "show" do
    before do
      user = FactoryBot.create(:admin)
      set_current_user(user)
      b_param = BParam.create(creator_id: user.id)
      get :show, id: b_param.id
    end
  end
end
