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

    it "calls update_ownership" do
      BikeUpdator.any_instance.should_receive(:update_ownership)
      bike = FactoryGirl.create(:bike)
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      put :update, id: bike.id
    end

    it "calls serial_normalizer" do
      SerialNormalizer.any_instance.should_receive(:save_segments)
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
        put :update, { id: bike.id, bike: { manufacturer_id: nil}}
      end
      it { should render_template(:edit) }
    end
  end

  describe :update_manufacturers do 
    it "updates the products" do 
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      request.env["HTTP_REFERER"] = 'http://lvh.me:3000/admin/bikes/missing_manufacturers'

      bike1 = FactoryGirl.create(:bike, manufacturer_other: 'hahaha')
      bike2 = FactoryGirl.create(:bike, manufacturer_other: '69')
      bike3 = FactoryGirl.create(:bike, manufacturer_other: '69')
      manufacturer = FactoryGirl.create(:manufacturer)
      update_params = {
        manufacturer_id: manufacturer.id,
        bikes_selected: { bike1.id => bike1.id, bike2.id => bike2.id }
      }
      post :update_manufacturers, update_params
      bike1.reload.manufacturer.should eq(manufacturer)
      bike2.reload.manufacturer.should eq(manufacturer)
      bike1.manufacturer_other.should be_nil
      bike2.manufacturer_other.should be_nil
      bike3.manufacturer_other.should eq('69') # Sanity check
    end
  end


end
