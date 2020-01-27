require "rails_helper"

RSpec.describe Admin::OwnershipsController, type: :controller do
  describe "edit" do
    it "renders" do
      ownership = FactoryBot.create(:ownership)
      user = FactoryBot.create(:admin)
      set_current_user(user)
      get :edit, params: { id: ownership.id }
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "update" do
    it "updates ownership" do
      ownership = FactoryBot.create(:ownership)
      og_creator = ownership.creator
      user = FactoryBot.create(:admin)
      set_current_user(user)
      update_params = {
        user_email: ownership.creator.email,
        creator_email: user.email,
        user_hidden: true,
      }
      put :update, params: { id: ownership.id, ownership: update_params }
      ownership.reload
      expect(ownership.user).to eq(og_creator)
      expect(ownership.user_hidden).to be_truthy
      expect(ownership.creator).to eq(user)
    end
  end
end
