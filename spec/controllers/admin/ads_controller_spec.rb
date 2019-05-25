require "spec_helper"

describe Admin::AdsController, type: :controller do
  describe "index" do
    before do
      user = FactoryBot.create(:admin)
      set_current_user(user)
      get :index
    end
  end
end
