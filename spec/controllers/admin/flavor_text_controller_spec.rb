require 'spec_helper'

describe Admin::FlavorTextsController do
  describe :destroy do 
    before do 
      text = FlavorText.create(message: "lulz")
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      delete :destroy, id: text.id
    end
    it { should redirect_to(:admin_root) }
    it { should set_the_flash }
  end

  describe :update do 
    describe "success" do 
      before do 
        user = FactoryGirl.create(:user, superuser: true)
        set_current_user(user)
        post :create, {flavor_text: {message: "lulz"}}
      end
      it { should redirect_to(:admin_root) }
      it { should set_the_flash }
    end
  end
end
