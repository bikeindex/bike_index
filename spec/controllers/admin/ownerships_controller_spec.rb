require 'spec_helper'

describe Admin::OwnershipsController do

  describe :edit do 
    before do 
      ownership = FactoryGirl.create(:ownership)
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :edit, id: ownership.id 
    end
    it { should respond_with(:success) }
    it { should render_template(:edit) }
    it { should_not set_the_flash }
  end

  describe :update do 
    describe "success" do 
      before do 
        ownership = FactoryGirl.create(:ownership)
        user = FactoryGirl.create(:admin)
        set_current_user(user)
        put :update, id: ownership.id
      end
      it { should redirect_to(:edit_ownership_bike) }
      it { should set_the_flash }
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
