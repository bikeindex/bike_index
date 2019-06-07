require "spec_helper"

describe Admin::RecoveriesController do
  before do
    let(:user) { FactoryBot.create(:admin) }
    set_current_user(user)
  end
  describe "index" do
    it "renders" do
      get :index
      expect(response).to be_success
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end
end
