require 'spec_helper'

describe Bike do

  describe :validations do
    it { should belong_to :manufacturer }
    it { should belong_to :primary_frame_color }
    it { should belong_to :secondary_frame_color }
    it { should belong_to :tertiary_frame_color }
    it { should belong_to :handlebar_type }
    it { should belong_to :rear_wheel_size }
    it { should belong_to :front_wheel_size }
    it { should belong_to :rear_gear_type }
    it { should belong_to :front_gear_type }
    it { should belong_to :frame_material }
    it { should belong_to :propulsion_type }
    it { should belong_to :cycle_type }
    it { should belong_to :creator }
    it { should belong_to :creation_organization }
    it { should belong_to :location }
    it { should have_many :b_params }
    it { should have_many :stolen_notifications }
    it { should have_many :stolen_records }
    it { should have_many :ownerships }
    it { should have_many :public_images }
    it { should have_many :components }
    it { should accept_nested_attributes_for :stolen_records }
    it { should accept_nested_attributes_for :components }
    it { should validate_presence_of :cycle_type_id }
    it { should validate_presence_of :propulsion_type_id }
    it { should validate_presence_of :creator }
    it { should validate_presence_of :serial_number }
    it { should validate_presence_of :manufacturer_id }
    it { should validate_presence_of :rear_wheel_size_id }
    it { should validate_presence_of :primary_frame_color_id }
    it { should serialize :cached_attributes }
  end


  describe "scopes" do 
    it "default scopes to created_at desc" do 
      Bike.scoped.to_sql.should == Bike.order("created_at desc").to_sql
    end
    it "scopes to only stolen bikes" do 
      Bike.stolen.to_sql.should == Bike.where(stolen: true).to_sql
    end
    it "non_stolen scopes to only non_stolen bikes" do 
      Bike.non_stolen.to_sql.should == Bike.where(stolen: false).to_sql
    end
    it "non_token scopes to only non_token bikes" do 
      Bike.non_token.to_sql.should == Bike.where(created_with_token: nil).to_sql
    end
  end

  describe :attr_cache_search do
    it "should find bikes by email address when the case doesn't match" do
      bike = FactoryGirl.create(:bike)
      query = ["c#{bike.primary_frame_color_id}"]
      result = Bike.attr_cache_search(query)
      result.first.should eq(bike)
      result.class.should eq(ActiveRecord::Relation)
    end
  end


  describe :owner do
    it "should receive owner from the last ownership" do
      first_ownership = Ownership.new 
      second_ownership = Ownership.new
      @user = User.new
      @bike = Bike.new 
      @bike.stub(:ownerships).and_return([first_ownership, second_ownership])
      second_ownership.stub(:owner).and_return(@user)
      @bike.owner.should eq(@user)
    end
  end

  describe :current_stolen_record do 
    it "should return the last current stolen record if bike is stolen" do 
      @bike = Bike.new 
      first_stolen_record = StolenRecord.new
      second_stolen_record = StolenRecord.new
      first_stolen_record.stub(:current).and_return(true)
      second_stolen_record.stub(:current).and_return(true)
      @bike.stub(:stolen).and_return(true)
      @bike.stub(:stolen_records).and_return([first_stolen_record, second_stolen_record])
      @bike.current_stolen_record.should eq(second_stolen_record)
    end

    it "should be false if the bike isn't stolen" do 
      @bike = Bike.new 
      @bike.stub(:stolen).and_return(false)
      @bike.current_stolen_record.should be_false
    end
  end

  describe :manufacturer_name do 
    it "should return the value of manufacturer_other if manufacturer is other" do 
      @bike = Bike.new
      other_manufacturer = Manufacturer.new 
      other_manufacturer.stub(:name).and_return("Other")
      @bike.stub(:manufacturer).and_return(other_manufacturer)
      @bike.stub(:manufacturer_other).and_return("Other manufacturer name")
      @bike.manufacturer_name.should eq("Other manufacturer name")
    end

    it "should return the name of the manufacturer if it isn't other" do
      @bike = Bike.new
      manufacturer = Manufacturer.new 
      manufacturer.stub(:name).and_return("Mnfg name")
      @bike.stub(:manufacturer).and_return(manufacturer)
      @bike.manufacturer_name.should eq("Mnfg name")
    end
  end

  describe :type do 
    it "should return the cycle type name" do 
      cycle_type = FactoryGirl.create(:cycle_type)
      bike = FactoryGirl.create(:bike, cycle_type: cycle_type)
      bike.type.should eq(cycle_type.name.downcase)
    end
  end

  describe :video_embed_src do 
    it "should return false if there is no video_embed" do 
      @bike = Bike.new 
      @bike.stub(:video_embed).and_return(nil)
      @bike.video_embed_src.should be_nil
    end

    it "should return just the url of the video from a youtube iframe" do 
      youtube_share = '''
          <iframe width="560" height="315" src="//www.youtube.com/embed/Sv3xVOs7_No" frameborder="0" allowfullscreen></iframe>
        '''
      @bike = Bike.new 
      @bike.stub(:video_embed).and_return(youtube_share)
      @bike.video_embed_src.should eq('//www.youtube.com/embed/Sv3xVOs7_No')
    end

    it "should return just the url of the video from a vimeo iframe" do 
      vimeo_share = '''<iframe src="http://player.vimeo.com/video/13094257" width="500" height="281" frameborder="0" webkitAllowFullScreen mozallowfullscreen allowFullScreen></iframe><p><a href="http://vimeo.com/13094257">Fixed Gear Kuala Lumpur, RatsKL Putrajaya</a> from <a href="http://vimeo.com/user3635109">irmanhilmi</a> on <a href="http://vimeo.com">Vimeo</a>.</p>'''
      @bike = Bike.new 
      @bike.stub(:video_embed).and_return(vimeo_share)
      @bike.video_embed_src.should eq('http://player.vimeo.com/video/13094257')
    end
  end


  describe "pg search" do 
    it "should return a bike which has a serial number from the query" do
      @bike = FactoryGirl.create(:bike, serial_number: "4444444sssss")
      @bikes = Bike.text_search("4444444sssss")
      @bikes.should include(@bike)
    end
    
    xit "should return a bike that has a serial number that includes the query" do 
      @bike = FactoryGirl.create(:bike, serial_number: "4sssss")
      @bikes = Bike.text_search("4444444sssss")
      @bikes.should include(@bike)
    end

    it "should not return a bike which does not have a matching serial number" do 
      @bike = FactoryGirl.create(:bike, serial_number: "4444444sssss")
      @bikes = Bike.text_search("5555ssss")
      @bikes.should_not include(@bike)
    end

    it "should return a bike which has a matching part of its description" do
      @bike = FactoryGirl.create(:bike, description: "Phil wood hub")
      @bikes = Bike.text_search("phil wood hub")
      @bikes.should include(@bike)
    end

    it "should return the bikes in the default scope pattern if there is no query" do 
      bike = FactoryGirl.create(:bike, description: "Phil wood hub")
      bike2 = FactoryGirl.create(:bike)
      bikes = Bike.text_search("")
      bikes.first.should eq(bike2)
    end
  end

  describe :cache_photo do 
    it "should cache the photo" do 
      bike = FactoryGirl.create(:bike)
      image = FactoryGirl.create(:public_image, imageable: bike)
      bike.cache_photo
      bike.thumb_path.should_not be_nil
    end
  end

  describe :components_cache_string do 
    it "should cache the components" do 
      bike = FactoryGirl.create(:bike)
      c = FactoryGirl.create(:component, bike: bike)
      bike.components_cache_string.should eq("#{c.ctype.name} ")
    end
  end

  describe :cache_attributes do 
    it "should cache the colors handlebar_type and wheel_size" do 
      color = FactoryGirl.create(:color)
      handlebar = FactoryGirl.create(:handlebar_type)
      wheel = FactoryGirl.create(:wheel_size)
      bike = FactoryGirl.create(:bike, secondary_frame_color: color, handlebar_type: handlebar, front_wheel_size: wheel)
      bike.cached_attributes[0].should eq("c#{bike.primary_frame_color_id}")
      bike.cached_attributes[1].should eq("c#{color.id}")
      bike.cached_attributes[2].should eq("h#{handlebar.id}")
      bike.cached_attributes[3].should eq("w#{bike.rear_wheel_size_id}")
      bike.cached_attributes[4].should eq("w#{wheel.id}")
    end
  end


  describe :cache_bike do 
    it "should call cache photo and cache component" do 
      bike = FactoryGirl.create(:bike)
      bike.should_receive(:cache_photo)
      bike.should_receive(:cache_attributes)
      bike.should_receive(:components_cache_string)
      bike.cache_bike
    end
    it "should cache all the bike parts" do 
      type = FactoryGirl.create(:cycle_type, name: "Unicycle")
      handlebar = FactoryGirl.create(:handlebar_type)
      material = FactoryGirl.create(:frame_material)
      propulsion = FactoryGirl.create(:propulsion_type, name: "Hand pedaled")
      b = FactoryGirl.create(:bike, cycle_type: type, propulsion_type_id: propulsion.id)
      b.frame_manufacture_year = 1999
      b.frame_material_id = material.id
      b.secondary_frame_color_id = b.primary_frame_color_id
      b.tertiary_frame_color_id = b.primary_frame_color_id
      b.frame_model = "Some model"
      b.handlebar_type_id = handlebar.id
      b.save
      b.cache_bike
      b.cached_data.should eq("Hand pedaled 1999 #{b.primary_frame_color.name} #{b.secondary_frame_color.name} #{b.tertiary_frame_color.name} #{material.name} #{b.frame_model} #{b.manufacturer_name} unicycle ")
    end
  end

end
