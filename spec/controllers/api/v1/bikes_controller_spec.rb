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
      @organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:membership, user: user, organization: @organization)
      @organization.save
      FactoryGirl.create(:cycle_type, name: "Bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
    end

    it "should email us work" do 
      lambda {
        post :create, { :bike => { serial_number: '69' }, organization_slug: @organization.slug, access_token: @organization.access_token }
      }.should change(Feedback, :count).by(1)
    end

    it "should create a record" do
      manufacturer = FactoryGirl.create(:manufacturer)
      f_count = Feedback.count
      bike = { serial_number: "69",
        cycle_type_id: FactoryGirl.create(:cycle_type).id,
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_size_id: FactoryGirl.create(:wheel_size).id,
        primary_frame_color_id: FactoryGirl.create(:color).id,
        handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
        owner_email: "fun_times@examples.com"
      }
      lambda { 
        post :create, { bike: bike, organization_slug: @organization.slug, access_token: @organization.access_token, keys_included: true }
      }.should change(Ownership, :count).by(1)
      Bike.last.creation_organization_id.should eq(@organization.id)
      response.code.should eq("200")
      f_count.should eq(Feedback.count)
    end

    it "should create email us if the record isn't pre_associated" do
      manufacturer = FactoryGirl.create(:manufacturer)
      bike = { serial_number: "69",
        cycle_type_id: FactoryGirl.create(:cycle_type).id,
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_size_id: FactoryGirl.create(:wheel_size).id,
        primary_frame_color_id: FactoryGirl.create(:color).id,
        handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
        owner_email: "fun_times@examples.com"
      }
      lambda { 
        post :create, { bike: bike, organization_slug: @organization.slug, access_token: @organization.access_token }
      }.should change(Feedback, :count).by(1)
    end
  end
    
end
