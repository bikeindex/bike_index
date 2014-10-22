require "spec_helper"

describe OwnershipsController do

  describe :show do
    describe "user not present" do
      before do 
        ownership = FactoryGirl.create(:ownership)
        put :show, id: ownership.id
      end
      it { should redirect_to(:new_session) }
      it { should set_the_flash }
    end

    describe "user present" do 
      before :each do 
        @user = FactoryGirl.create(:user)
        @ownership = FactoryGirl.create(:ownership)
        set_current_user(@user)
      end
      
      it "redirects and not change the ownership" do
        put :show, id: @ownership.id
        response.code.should eq('302')
        flash.should be_present 
        @ownership.reload.claimed.should be_false
      end
      
      it "redirects and not change the ownership if it isn't current" do
        @ownership.update_attributes(owner_email: @user.email, current: false)
        put :show, id: @ownership.id
        response.code.should eq('302')
        flash.should be_present
        @ownership.reload.claimed.should be_false
      end
  
      it "redirects and mark current based on fuzzy find" do
        @ownership.update_attributes(owner_email: @user.email.upcase)
        put :show, id: @ownership.id
        response.code.should eq('302')
        response.should redirect_to edit_bike_url(@ownership.bike)
        flash.should be_present 
        @ownership.reload.claimed.should be_true
      end
    end
  end

  
end
