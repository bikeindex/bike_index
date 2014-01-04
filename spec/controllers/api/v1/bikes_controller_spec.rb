require 'spec_helper'

describe Api::V1::BikesController do
  
  describe :index do
    it "should load the page and have the correct headers" do
      FactoryGirl.create(:bike)
      get :index, format: :json
      response.code.should eq('200')
    end
  end

  describe :show do
    it "should load the page" do
      bike = FactoryGirl.create(:bike)
      get :show, id: bike.id, format: :json
      response.code.should eq("200")
    end
  end

  describe :create do 
    before :each do
      @user = FactoryGirl.create(:user)
      @b_param = FactoryGirl.create(:b_param, creator: @user)
      FactoryGirl.create(:cycle_type, name: "Bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      manufacturer = FactoryGirl.create(:manufacturer)
      session[:user_id] = @user.id
      @bike = { serial_number: "1234567890",
        b_param_id: @b_param.id,
        cycle_type_id: FactoryGirl.create(:cycle_type).id,
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_size_id: FactoryGirl.create(:wheel_size).id,
        primary_frame_color_id: FactoryGirl.create(:color).id,
        handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
        owner_email: @user.email
      }
    end

    it "should create a record" do
      post :create
      response.code.should eq("200")
    end

    it "should email me if stuff doesn't work" do 
      lambda {
        post :create
      }.should change(Feedback, :count).by(1)
    end
  end
    
end
