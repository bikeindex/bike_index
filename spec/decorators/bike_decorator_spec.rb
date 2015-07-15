require 'spec_helper'

describe BikeDecorator do

  describe :show_other_bikes do 
    it "links to bikes if the user is the current owner and wants to share" do 
      bike = Bike.new
      user = User.new 
      bike.stub(:owner).and_return(user)
      user.stub(:show_bikes).and_return(true)
      user.stub(:username).and_return("i")
      decorator = BikeDecorator.new(bike)
      bike.stub(:current_owner_exists).and_return(true)
      decorator.show_other_bikes.match("href='/users/i").should be_present
    end
  end

  describe :bike_show_twitter_and_website do
    it "calls the method from application decorator" do 
      user = User.new
      bike = Bike.new
      bike.stub(:owner).and_return(user)
      decorator = BikeDecorator.new(bike)
      bike.stub(:current_owner_exists).and_return(true)
      decorator.should_receive(:show_twitter_and_website).with(user)
      decorator.bike_show_twitter_and_website
    end
  end

  describe :title do 
    it "returns the major bike attribs formatted" do 
      bike = Bike.new
      bike.stub(:year).and_return("1999")
      bike.stub(:frame_model).and_return("model")
      bike.stub(:mnfg_name).and_return("foo")
      decorator = BikeDecorator.new(bike)
      decorator.title.should eq("<span>1999 model by </span><strong>foo</strong>")
    end
  end

  describe :phoneable_by do 
    it "does not return anything if there isn't a stolen record" do 
      bike = Bike.new
      BikeDecorator.new(bike).phoneable_by.should be_nil
    end
    it "returns true if users can see it" do 
      bike = Bike.new 
      stolen_record = StolenRecord.new
      bike.stub(:stolen).and_return(true)
      bike.stub(:current_stolen_record).and_return(stolen_record)
      stolen_record.stub(:phone_for_everyone).and_return(true)
      BikeDecorator.new(bike).phoneable_by.should be_true
    end

    it "returns true if users can see it and user is there" do 
      user = User.new
      bike = Bike.new 
      stolen_record = StolenRecord.new
      bike.stub(:stolen).and_return(true)
      bike.stub(:current_stolen_record).and_return(stolen_record)
      stolen_record.stub(:phone_for_users).and_return(true)
      BikeDecorator.new(bike).phoneable_by(user).should be_true
    end

    it "returns true if shops can see it and user has shop membership" do 
      user = User.new
      bike = Bike.new 
      stolen_record = StolenRecord.new
      user.stub(:has_shop_membership?).and_return(true)
      bike.stub(:stolen).and_return(true)
      bike.stub(:current_stolen_record).and_return(stolen_record)
      stolen_record.stub(:phone_for_users).and_return(false)
      stolen_record.stub(:phone_for_shops).and_return(true)
      BikeDecorator.new(bike).phoneable_by(user).should be_true
    end

    it "returns true if police can see it and user is police" do 
      user = User.new
      bike = Bike.new 
      stolen_record = StolenRecord.new
      user.stub(:has_police_membership?).and_return(true)
      bike.stub(:stolen).and_return(true)
      bike.stub(:current_stolen_record).and_return(stolen_record)
      stolen_record.stub(:phone_for_users).and_return(false)
      stolen_record.stub(:phone_for_shops).and_return(false)
      stolen_record.stub(:phone_for_police).and_return(true)
      BikeDecorator.new(bike).phoneable_by(user).should be_true
    end

    it "returns true for superusers" do 
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
    it "returns wide if false" do 
      bike = Bike.new
      bike.stub(:front_tire_narrow).and_return(nil)
      decorator = BikeDecorator.new(bike).tire_width("front")
      decorator.should eq("wide")
    end
    it "returns narrow if narrow" do 
      bike = Bike.new
      bike.stub(:rear_tire_narrow).and_return(true)
      decorator = BikeDecorator.new(bike).tire_width("rear")
      decorator.should eq("narrow")
    end
  end

  describe :list_link_url do 
    it "returns the bike edit path if edit" do 
      bike = Bike.new 
      bike.stub(:id).and_return(69)
      decorator = BikeDecorator.new(bike).list_link_url("edit")
      decorator.should eq("/bikes/69/edit")
    end

    it "returns the normal path if passed" do 
      bike = Bike.new 
      bike.stub(:id).and_return(69)
      decorator = BikeDecorator.new(bike).list_link_url()
      decorator.should eq("/bikes/69")
    end
  end

  describe :thumb_image do 
    it "returns the thumb path if one exists" do 
      bike = Bike.new
      bike.stub(:thumb_path).and_return("pathy")
      decorator = BikeDecorator.new(bike)
      decorator.stub(:title_string).and_return("Title")
      decorator.thumb_image.should eq("<img alt=\"Title\" src=\"/assets/pathy\" />")
    end
  end

  describe :list_image do 
    it "returns the link with  thumb path if nothing is passed" do 
      bike = Bike.new
      bike.stub(:id).and_return(69)
      decorator = BikeDecorator.new(bike)
      decorator.stub(:thumb_image).and_return("imagey")
      decorator.list_image.should_not be_nil
    end
    it "returns the images thumb path" do 
      bike = Bike.new
      bike.stub(:id).and_return(69)
      bike.stub(:thumb_path).and_return("something")
      decorator = BikeDecorator.new(bike)
      decorator.stub(:thumb_image).and_return("imagey")
      decorator.list_image.should_not be_nil
    end
  end

end
