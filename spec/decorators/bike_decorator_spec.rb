require 'spec_helper'

describe BikeDecorator do

  describe :current_owner_exists do 
    it "should make sure that the current owner exists" do 
      # if you send the bike to a new owner, the creator has edit rights
      # We want to differentiate the two
      bike = Bike.new
      ownership = Ownership.new 
      bike.stub(:current_ownership).and_return(ownership)
      ownership.stub(:claimed).and_return(true)
      BikeDecorator.new(bike).current_owner_exists.should be_true
    end
  end

  describe :can_be_claimed_by do 
    it "should return true if the bike can be claimed" do 
      user = User.new
      ownership = Ownership.new
      bike = Bike.new
      bike.stub(:current_ownership).and_return(ownership)
      ownership.stub(:user).and_return(user)
      decorator = BikeDecorator.new(bike)
      decorator.stub(:current_owner_exists).and_return(false)
      decorator.can_be_claimed_by(user).should be_true
    end
  end

  describe :show_other_bikes do 
    it "should link to bikes if the user is the current owner and wants to share" do 
      bike = Bike.new
      user = User.new 
      bike.stub(:owner).and_return(user)
      user.stub(:show_bikes).and_return(true)
      user.stub(:username).and_return("i")
      decorator = BikeDecorator.new(bike)
      decorator.stub(:current_owner_exists).and_return(true)
      decorator.show_other_bikes.should eq("<a href='/users/i'>Check out this biker's other bikes</a>")
    end
  end

  describe :bike_show_twitter_and_website do
    it "should call the method from application decorator" do 
      user = User.new
      bike = Bike.new
      bike.stub(:owner).and_return(user)
      decorator = BikeDecorator.new(bike)
      decorator.stub(:current_owner_exists).and_return(true)
      decorator.should_receive(:show_twitter_and_website).with(user)
      decorator.bike_show_twitter_and_website
    end
  end

  describe :title do 
    it "should return the major bike attribs formatted" do 
      bike = Bike.new
      bike.stub(:frame_manufacture_year).and_return("1999")
      bike.stub(:frame_model).and_return("model")
      decorator = BikeDecorator.new(bike)
      decorator.stub(:mnfg_name).and_return("foo")
      decorator.title.should eq("<span>1999 model by </span><strong>foo</strong>")
    end
  end

  describe :phoneable_by do 
    it "shouldn't return anything if there isn't a stolen record" do 
      bike = Bike.new
      BikeDecorator.new(bike).phoneable_by.should be_nil
    end
    it "should return true if users can see it" do 
      bike = Bike.new 
      stolen_record = StolenRecord.new
      bike.stub(:stolen).and_return(true)
      bike.stub(:current_stolen_record).and_return(stolen_record)
      stolen_record.stub(:phone_for_everyone).and_return(true)
      BikeDecorator.new(bike).phoneable_by.should be_true
    end

    it "should return true if users can see it and user is there" do 
      user = User.new
      bike = Bike.new 
      stolen_record = StolenRecord.new
      bike.stub(:stolen).and_return(true)
      bike.stub(:current_stolen_record).and_return(stolen_record)
      stolen_record.stub(:phone_for_users).and_return(true)
      BikeDecorator.new(bike).phoneable_by(user).should be_true
    end

    it "should return true if shops can see it and user has membership" do 
      user = User.new
      bike = Bike.new 
      stolen_record = StolenRecord.new
      user.stub(:has_membership?).and_return(true)
      bike.stub(:stolen).and_return(true)
      bike.stub(:current_stolen_record).and_return(stolen_record)
      stolen_record.stub(:phone_for_users).and_return(false)
      stolen_record.stub(:phone_for_shops).and_return(true)
      BikeDecorator.new(bike).phoneable_by(user).should be_true
    end

    it "should return true for superusers" do 
      user = User.new
      bike = Bike.new 
      stolen_record = StolenRecord.new
      user.stub(:superuser).and_return(true)
      bike.stub(:stolen).and_return(true)
      bike.stub(:current_stolen_record).and_return(stolen_record)
      stolen_record.stub(:phone_for_users).and_return(false)
      stolen_record.stub(:phone_for_shops).and_return(false)
      stolen_record.stub(:phone_for_police).and_return(false)
      BikeDecorator.new(bike).phoneable_by(user).should be_true
    end
  end

  describe :tire_width do 
    it "should return wide if false" do 
      bike = Bike.new
      bike.stub(:front_tire_narrow).and_return(nil)
      decorator = BikeDecorator.new(bike).tire_width("front")
      decorator.should eq("wide")
    end
    it "should return narrow if narrow" do 
      bike = Bike.new
      bike.stub(:rear_tire_narrow).and_return(true)
      decorator = BikeDecorator.new(bike).tire_width("rear")
      decorator.should eq("narrow")
    end
  end

  describe :list_link_url do 
    it "should return the bike edit path if edit" do 
      bike = Bike.new 
      bike.stub(:id).and_return(69)
      decorator = BikeDecorator.new(bike).list_link_url("edit")
      decorator.should eq("/bikes/69/edit")
    end

    it "should return the normal path if passed" do 
      bike = Bike.new 
      bike.stub(:id).and_return(69)
      decorator = BikeDecorator.new(bike).list_link_url()
      decorator.should eq("/bikes/69")
    end
  end

  describe :thumb_image do 
    it "should return the thumb path if one exists" do 
      bike = Bike.new
      bike.stub(:thumb_path).and_return("pathy")
      decorator = BikeDecorator.new(bike)
      decorator.stub(:title).and_return("Title")
      decorator.thumb_image.should eq("<img alt=\"Title\" src=\"/assets/pathy\" />")
    end
    it "should return the placeholder url otherwise" do 
      bike = Bike.new
      bike.stub(:thumb_path).and_return(nil)
      decorator = BikeDecorator.new(bike)
      decorator.stub(:title).and_return("Title")
      decorator.thumb_image.should eq("<img alt=\"Title\" src=\"/assets/bike_photo_placeholder.png\" /><span>no image</span>")
    end
  end

  describe :list_image do 
    it "should return the link with  thumb path if nothing is passed" do 
      bike = Bike.new
      bike.stub(:id).and_return(69)
      decorator = BikeDecorator.new(bike)
      decorator.stub(:thumb_image).and_return("imagey")
      decorator.list_image.should_not be_nil
    end
    it "should return the images thumb path" do 
      bike = Bike.new
      bike.stub(:id).and_return(69)
      bike.stub(:thumb_path).and_return("something")
      decorator = BikeDecorator.new(bike)
      decorator.stub(:thumb_image).and_return("imagey")
      decorator.list_image.should_not be_nil
    end
  end

  describe :frame_colors do 
    it "should return an array of the frame colors" do 
      bike = Bike.new 
      decorator = BikeDecorator.new(bike)
      color = Color.new
      color2 = Color.new
      color.stub(:name).and_return('Blue')
      color2.stub(:name).and_return('Black')
      bike.stub(:primary_frame_color).and_return(color)
      bike.stub(:secondary_frame_color).and_return(color2)
      bike.stub(:tertiary_frame_color).and_return(color)
      decorator.frame_colors.should eq(['Blue', 'Black', 'Blue'])
    end
  end

end