require 'spec_helper'

describe ApplicationDecorator do

  describe :mnfg_name do 
    it "should return the manufacturer other name if present" do 
      manufacturer = Manufacturer.new
      lock = Lock.new
      manufacturer.stub(:name).and_return("Other")
      lock.stub(:manufacturer).and_return(manufacturer)
      lock.stub(:manufacturer_other).and_return("Other name")
      ApplicationDecorator.new(lock).mnfg_name.should eq("Other name")
    end
    it "should return the manufacturer name" do 
      manufacturer = Manufacturer.new
      lock = Lock.new
      manufacturer.stub(:name).and_return("Another")
      lock.stub(:manufacturer).and_return(manufacturer)
      ApplicationDecorator.new(lock).mnfg_name.should eq("Another")
    end
  end

  describe :dl_list_item do
    it "should return a dt and dd from what's passed attribute" do 
      bike = Bike.new
      dl_list = ApplicationDecorator.new(bike).dl_list_item("description", "title")
      dl_list.should eq("<dt>title</dt><dd>description</dd>")
    end
  end

  describe :dl_from_attribute do 
    it "should return nil if the attribute isn't present" do 
      bike = Bike.new
      decorator = ApplicationDecorator.new(bike)
      decorator.stub(:if_present).and_return(nil)
      decorator.dl_from_attribute("serial_number").should be_nil
    end    
    it "should return a dt and dd from the attribute" do 
      bike = Bike.new
      decorator = ApplicationDecorator.new(bike)
      decorator.stub(:if_present).and_return("cereal")
      decorator.should_receive(:dl_list_item).with("cereal", "Serial Number")
      decorator.dl_from_attribute("serial_number")
    end
  end

  describe :dl_from_attribute_othered do 
    it "should return the attribute dl" do 
      bike = Bike.new
      handlebar_type = HandlebarType.new 
      bike.stub(:handlebar_type).and_return(handlebar_type)
      handlebar_type.stub(:name).and_return("Cookie")
      decorator = ApplicationDecorator.new(bike)
      decorator.should_receive(:dl_list_item).with("Cookie", "Handlebar Type")
      decorator.dl_from_attribute_othered("handlebar_type")
    end
    it "should return the other attribute dl" do 
      bike = Bike.new
      handlebar_type = HandlebarType.new 
      bike.stub(:handlebar_type).and_return(handlebar_type)
      bike.stub(:handlebar_type_other).and_return("Another type")
      handlebar_type.stub(:name).and_return("Other style")
      decorator = ApplicationDecorator.new(bike)
      decorator.should_receive(:dl_list_item).with("Another type", "Handlebar Type")
      decorator.dl_from_attribute_othered("handlebar_type")
    end
  end

  describe :if_present do 
    it "should return the attribute if it's present" do 
      lock = Lock.new
      lock.stub(:manufacturer_other).and_return("thingsy")
      ApplicationDecorator.new(lock).if_present("manufacturer_other").should eq("thingsy")
    end
  end

  describe :websiteable do 
    it "should create a link if bike owner wants one shown" do 
      user = User.new 
      user.stub(:show_website).and_return(true)
      user.stub(:website).and_return("website")
      decorator = ApplicationDecorator.new(user).websiteable(user)
      decorator.should eq('<a href="website">Website</a>')
    end
  end

  describe :twitterable do 
    it "should create a link if bike owner wants one shown" do 
      user = User.new 
      user.stub(:show_twitter).and_return(true)
      user.stub(:twitter).and_return("twitter")
      decorator = ApplicationDecorator.new(user).twitterable(user)
      decorator.should eq('<a href="https://twitter.com/twitter">Twitter</a>')
    end
  end

  describe :show_twitter_and_website do 
    it "should combine twitter and website" do 
      user = User.new
      decorator = ApplicationDecorator.new(user)
      decorator.stub(:twitterable).and_return("twitter")
      decorator.stub(:websiteable).and_return("website")
      decorator.show_twitter_and_website(user).should eq("twitter and website")
    end
    it "should just return website if no twitter" do 
      user = User.new
      decorator = ApplicationDecorator.new(user)
      decorator.stub(:current_owner_exists).and_return(true)
      decorator.stub(:twitterable).and_return(nil)
      decorator.stub(:websiteable).and_return("website")
      decorator.show_twitter_and_website(user).should eq("website")
    end
  end

  describe :ass_name do 
    it "should grab the association name" do 
      bike = Bike.new 
      handlebar_type = FactoryGirl.create(:handlebar_type, name: "cool bars")
      bike.stub(:handlebar_type).and_return(handlebar_type)
      ApplicationDecorator.new(bike).ass_name("handlebar_type").should eq("cool bars")
    end
  end

  describe :display_phone do 
    it "should display the phone with an area code" do 
      location = Location.new 
      location.stub(:phone).and_return("999 999 9999")
      ApplicationDecorator.new(location).display_phone.should eq("999 999 9999")
    end
    it "should display the phone with a country code" do 
      location = Location.new 
      location.stub(:phone).and_return("+91 8041505583")
      ApplicationDecorator.new(location).display_phone.should eq("+91 804 150 5583")
    end
  end

end