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

    it "should return correct code if not logged in" do 
      c = FactoryGirl.create(:color)
      post :create, { :bike => { serial_number: '69', color: c.name } }
      response.code.should eq("401")
    end

    it "should return correct code if bike has errors" do 
      c = FactoryGirl.create(:color)
      post :create, { :bike => { serial_number: '69', color: c.name }, organization_slug: @organization.slug, access_token: @organization.access_token }
      response.code.should eq("422")
    end

    it "should email us if it can't create a record" do 
      c = FactoryGirl.create(:color)
      lambda {
        post :create, { :bike => { serial_number: '69', color: c.name }, organization_slug: @organization.slug, access_token: @organization.access_token }
      }.should change(Feedback, :count).by(1)
    end

    it "should create a record and reset example" do
      manufacturer = FactoryGirl.create(:manufacturer)
      FactoryGirl.create(:cycle_type, slug: "bike")
      f_count = Feedback.count
      bike = { serial_number: "69 non-example",
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_size_id: FactoryGirl.create(:wheel_size).id,
        color: FactoryGirl.create(:color).name,
        example: true,
        owner_email: "fun_times@examples.com"
      }
      OwnershipCreator.any_instance.should_receive(:send_notification_email)
      lambda { 
        post :create, { bike: bike, organization_slug: @organization.slug, access_token: @organization.access_token }
      }.should change(Ownership, :count).by(1)
      response.code.should eq("200")
      b = Bike.where(serial_number: "69 non-example").first
      b.example.should be_false
      b.creation_organization_id.should eq(@organization.id)
      f_count.should eq(Feedback.count)
    end

    it "should create a stolen record" do
      manufacturer = FactoryGirl.create(:manufacturer)
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:country, iso: "Candyland")
      FactoryGirl.create(:state, abbreviation: "Palace")
      bike = { serial_number: "69 stolen bike",
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_size_id: FactoryGirl.create(:wheel_size).id,
        primary_frame_color_id: FactoryGirl.create(:color).id,
        owner_email: "fun_times@examples.com",
        stolen: "true",
        phone: "9999999"
      }
      stolen_record = { date_stolen: "03-01-2013",
        theft_description: "This bike was stolen and that's no fair.",
        country: "Candyland",
        street: "Cortland and Ashland",
        zipcode: "60622",
        state: "Palace",
        police_report_number: "99999999",
        police_report_department: "Chicago"
      }
      OwnershipCreator.any_instance.should_receive(:send_notification_email)
      lambda { 
        post :create, { bike: bike, stolen_record: stolen_record, organization_slug: @organization.slug, access_token: @organization.access_token }
      }.should change(Ownership, :count).by(1)
      response.code.should eq("200")
      b = Bike.unscoped.where(serial_number: "69 stolen bike").first
      b.current_stolen_record.address.should be_present
      b.current_stolen_record.phone.should eq("9999999")
      b.current_stolen_record.date_stolen.should eq(DateTime.strptime("03-01-2013 06", "%m-%d-%Y %H"))
    end

    it "should create an example bike if the bike is from example, and include all the options" do
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:color, name: "Black")
      org = FactoryGirl.create(:organization, name: "Example organization")
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:membership, user: user, organization: org)
      manufacturer = FactoryGirl.create(:manufacturer)
      org.save
      bike = { serial_number: "69 example bike",
        cycle_type_id: FactoryGirl.create(:cycle_type, slug: 'gluey').id,
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_size_id: FactoryGirl.create(:wheel_size).id,
        color: "grazeen",
        handlebar_type_slug: FactoryGirl.create(:handlebar_type, slug: "foo").slug,
        frame_material_slug: FactoryGirl.create(:frame_material, slug: "whatevah").slug,
        description: "something else",
        owner_email: "fun_times@examples.com"
      }
      Resque.should_not_receive(:enqueue).with(OwnershipInvitationEmailJob, 1)
      lambda { 
        post :create, { bike: bike, organization_slug: org.slug, access_token: org.access_token }
      }.should change(Ownership, :count).by(1)
      response.code.should eq("200")
      b = Bike.unscoped.where(serial_number: "69 example bike").first
      b.example.should be_true
      b.paint.name.should eq("grazeen")
      b.description.should eq("something else")
      b.frame_material.slug.should eq("whatevah")
      b.handlebar_type.slug.should eq("foo")
    end
  end
    
end
