require 'spec_helper'

describe Admin::BikesController do

  describe :index do 
    before do 
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
    it { should_not set_the_flash }
  end

  describe :edit do 
    before do 
      bike = FactoryGirl.create(:bike)
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      get :edit, id: bike.id 
    end
    it { should respond_with(:success) }
    it { should render_template(:edit) }
    it { should_not set_the_flash }
  end

  describe :destroy do 
    before do 
      bike = FactoryGirl.create(:bike)
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      delete :destroy, id: bike.id 
    end
    it { should redirect_to(:admin_bikes) }
    it { should set_the_flash }
  end

  describe :update do 
    describe "success" do 
      before do 
        bike = FactoryGirl.create(:bike)
        user = FactoryGirl.create(:user, superuser: true)
        set_current_user(user)
        put :update, id: bike.id
      end
      it { should redirect_to(:edit_admin_bike) }
      it { should set_the_flash }
    end

    it "should call update_ownership" do
      BikeUpdator.any_instance.should_receive(:update_ownership)
      bike = FactoryGirl.create(:bike)
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      put :update, id: bike.id
    end

    describe "failure" do 
      before do 
        bike = FactoryGirl.create(:bike)
        user = FactoryGirl.create(:user, superuser: true)
        set_current_user(user)
        put :update, { id: bike.id, :bike => { manufacturer_id: nil}}
      end
      it { should render_template(:edit) }
    end
  end


end
