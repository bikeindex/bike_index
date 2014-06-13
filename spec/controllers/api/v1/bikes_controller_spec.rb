require 'spec_helper'

describe Api::V1::BikesController do
  
  describe :index do
    it "should load the page and have the correct headers" do
      FactoryGirl.create(:bike)
      get :index, format: :json
      response.code.should eq('200')
    end
  end

  describe :stolen_ids do
    it "should return correct code if no org" do 
      c = FactoryGirl.create(:color)
      get :stolen_ids, format: :json
      response.code.should eq("401")
    end

    xit "should return an array of ids" do
      bike = FactoryGirl.create(:bike)
      stole1 = FactoryGirl.create(:stolen_record)
      stole2 = FactoryGirl.create(:stolen_record, approved: true)
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:membership, user: user, organization: organization)
      options = { stolen: true, organization_slug: organization.slug, access_token: organization.access_token}
      get :stolen_ids, options, format: :json
      response.code.should eq('200')
      pp response
      bikes = JSON.parse(response.body)
      bikes.count.should eq(1)
      bikes.first.should eq(stole2.bike.id)
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
      FactoryGirl.create(:wheel_size, iso_bsd: 559)
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:ctype, name: "wheel")
      FactoryGirl.create(:ctype, name: "headset")
      f_count = Feedback.count
      bike = { serial_number: "69 non-example",
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_bsd: "559",
        color: FactoryGirl.create(:color).name,
        example: true,
        year: '1969',
        owner_email: "fun_times@examples.com"
      }
      components = [
        {
          manufacturer: manufacturer.name,
          year: "1999",
          component_type: 'Headset',
          cgroup: "Frame and fork",
          description: "yeah yay!",
          serial_number: '69',
          model_name: 'Richie rich'
        },
        {
          manufacturer: "BLUE TEETH",
          front_or_rear: "Both",
          cgroup: "Wheels",
          component_type: 'wheel'
        }
      ]
      photos = [
        'http://i.imgur.com/lybYl1l.jpg',
        'http://i.imgur.com/3BGQeJh.jpg'
      ]
      OwnershipCreator.any_instance.should_receive(:send_notification_email)
      lambda { 
        post :create, { bike: bike, organization_slug: @organization.slug, access_token: @organization.access_token, components: components, photos: photos}
      }.should change(Ownership, :count).by(1)
      response.code.should eq("200")
      b = Bike.where(serial_number: "69 non-example").first
      b.example.should be_false
      b.creation_organization_id.should eq(@organization.id)
      b.year.should eq(1969)
      b.components.count.should eq(3)
      b.components.first.serial_number.should eq('69')
      b.components.first.description.should eq("yeah yay!")
      b.components.first.ctype.slug.should eq("headset")
      b.components.first.year.should eq(1999)
      b.components.first.manufacturer_id.should eq(manufacturer.id)
      b.components.first.model_name.should eq('Richie rich')
      b.public_images.count.should eq(2)
      f_count.should eq(Feedback.count)
    end

    it "should create a photos even inf one fails" do
      manufacturer = FactoryGirl.create(:manufacturer)
      FactoryGirl.create(:wheel_size, iso_bsd: 559)
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:ctype, name: "wheel")
      FactoryGirl.create(:ctype, name: "headset")
      f_count = Feedback.count
      bike = { serial_number: "69 photo-test",
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_bsd: "559",
        color: FactoryGirl.create(:color).name,
        example: true,
        year: '1969',
        owner_email: "fun_times@examples.com"
      }
      photos = [
        'http://i.imgur.com/lybYl1l.jpg',
        'http://bikeindex.org/not_actually_a_thing_404_and_shit'
      ]
      post :create, { bike: bike, organization_slug: @organization.slug, access_token: @organization.access_token, photos: photos}
      b = Bike.where(serial_number: "69 photo-test").first
      b.public_images.count.should eq(1)
    end

    it "should create a stolen record" do
      manufacturer = FactoryGirl.create(:manufacturer)
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:country, iso: "US")
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
        country: "US",
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

    it "should create a record even if the post is a string" do
      manufacturer = FactoryGirl.create(:manufacturer)
      FactoryGirl.create(:wheel_size, iso_bsd: 559)
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:ctype, slug: "wheel")
      FactoryGirl.create(:ctype, slug: "headset")
      f_count = Feedback.count
      bike = { serial_number: "69 string",
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_bsd: "559",
        color: FactoryGirl.create(:color).name,
        owner_email: "jsoned@examples.com"
      }
      options = { bike: bike.to_json, organization_slug: @organization.slug, access_token: @organization.access_token } 
      lambda { 
        post :create, options
      }.should change(Ownership, :count).by(1)
      response.code.should eq("200")    
    end

    it "should not send an ownership email if it has no_email set" do
      manufacturer = FactoryGirl.create(:manufacturer)
      FactoryGirl.create(:wheel_size, iso_bsd: 559)
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:ctype, slug: "wheel")
      FactoryGirl.create(:ctype, slug: "headset")
      f_count = Feedback.count
      bike = { serial_number: "69 string",
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_bsd: "559",
        color: FactoryGirl.create(:color).name,
        owner_email: "jsoned@examples.com",
        send_email: 'false'
      }
      options = { bike: bike.to_json, organization_slug: @organization.slug, access_token: @organization.access_token } 
      Resque.should_not_receive(:enqueue)
      lambda { 
        post :create, options
      }.should change(Ownership, :count).by(1)
      response.code.should eq("200")
    end
  end

  describe :send_notification_email do 
    it "should return correct code if not logged in" do 
      bike = FactoryGirl.create(:bike)
      options = { title: 'some email title',
        body: 'some email text',
        bike_id: bike.id
      } 
      post :send_notification_email, options
      response.code.should eq("401")
    end

    it "should not send an email if the org is example" do
      organization = FactoryGirl.create(:organization, name: 'Example')
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:membership, user: user, organization: organization)
      organization.save
      bike = FactoryGirl.create(:bike)
      options = { title: 'some email title',
        body: 'some email text',
        bike_id: bike.id,
        organization_slug: organization.slug,
        access_token: organization.access_token
      } 
      Resque.should_not_receive(:enqueue)
      post :send_notification_email, options
      response.code.should eq("422")
    end

    it "should send an ownership email" do
      organization = FactoryGirl.create(:organization, short_name: 'example')
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:membership, user: user, organization: organization)
      organization.save
      bike = FactoryGirl.create(:bike)
      options = { title: 'some email title',
        body: 'some email text',
        bike_id: bike.id,
        organization_slug: organization.slug,
        access_token: organization.access_token
      } 
      Resque.should_not_receive(:enqueue)
      post :send_notification_email, options
      response.code.should eq("422")
    end

  end


    
end
