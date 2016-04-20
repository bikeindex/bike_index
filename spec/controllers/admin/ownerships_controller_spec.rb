require 'spec_helper'

describe Admin::OwnershipsController do
  describe 'edit' do
    before do
      ownership = FactoryGirl.create(:ownership)
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :edit, id: ownership.id 
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:edit) }
    it { is_expected.not_to set_the_flash }
  end

  describe 'update' do
    describe "success" do
      before do
        ownership = FactoryGirl.create(:ownership)
        user = FactoryGirl.create(:admin)
        set_current_user(user)
        put :update, id: ownership.id
      end
      it { is_expected.to redirect_to(:edit_admin_ownership) }
      it { is_expected.to set_the_flash }
    end

    it "updates ownership" do
      ownership = FactoryGirl.create(:ownership)
      og_creator = ownership.creator
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      update_params = {
        user_email: ownership.creator.email,
        creator_email: user.email
      }
      put :update, {id: ownership.id, ownership: update_params}
      ownership.reload
      expect(ownership.user).to eq(og_creator)
      expect(ownership.creator).to eq(user)
    end

  end

end
