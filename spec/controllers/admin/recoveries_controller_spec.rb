require "rails_helper"

RSpec.describe Admin::RecoveriesController, type: :controller do
  describe "index" do
    it "renders" do
      user = FactoryBot.create(:admin)
      set_current_user(user)
      get :index
      expect(response).to be_success
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end
end
