require 'spec_helper'

describe ApplicationDecorator do

  describe 'mnfg_name' do
    it "returns the manufacturer other name if present" do
      manufacturer = Manufacturer.new
      lock = Lock.new
      allow(manufacturer).to receive(:name).and_return("Other")
      allow(lock).to receive(:manufacturer).and_return(manufacturer)
      allow(lock).to receive(:manufacturer_other).and_return("Other name")
      expect(ApplicationDecorator.new(lock).mnfg_name).to eq("Other name")
    end
    it "returns the manufacturer name" do
      manufacturer = Manufacturer.new
      lock = Lock.new
      allow(manufacturer).to receive(:name).and_return("Another")
      allow(lock).to receive(:manufacturer).and_return(manufacturer)
      expect(ApplicationDecorator.new(lock).mnfg_name).to eq("Another")
    end
  end

  describe 'dl_list_item' do
    it "returns a dt and dd from what's passed attribute" do
      bike = Bike.new
      dl_list = ApplicationDecorator.new(bike).dl_list_item("description", "title")
      expect(dl_list).to eq("<dt>title</dt><dd>description</dd>")
    end
  end

  describe 'dl_from_attribute' do
    it "returns nil if the attribute isn't present" do
      bike = Bike.new
      decorator = ApplicationDecorator.new(bike)
      allow(decorator).to receive(:if_present).and_return(nil)
      expect(decorator.dl_from_attribute("serial_number")).to be_nil
    end    
    it "returns a dt and dd from the attribute" do
      bike = Bike.new
      decorator = ApplicationDecorator.new(bike)
      allow(decorator).to receive(:if_present).and_return("cereal")
      expect(decorator).to receive(:dl_list_item).with("cereal", "Serial Number")
      decorator.dl_from_attribute("serial_number")
    end
  end

  describe 'dl_from_attribute_othered' do
    it "returns the attribute dl" do
      bike = Bike.new
      handlebar_type = HandlebarType.new 
      allow(bike).to receive(:handlebar_type).and_return(handlebar_type)
      allow(handlebar_type).to receive(:name).and_return("Cookie")
      decorator = ApplicationDecorator.new(bike)
      expect(decorator).to receive(:dl_list_item).with("Cookie", "Handlebar Type")
      decorator.dl_from_attribute_othered("handlebar_type")
    end
    it "returns the other attribute dl" do
      bike = Bike.new
      handlebar_type = HandlebarType.new 
      allow(bike).to receive(:handlebar_type).and_return(handlebar_type)
      allow(bike).to receive(:handlebar_type_other).and_return("Another type")
      allow(handlebar_type).to receive(:name).and_return("Other style")
      decorator = ApplicationDecorator.new(bike)
      expect(decorator).to receive(:dl_list_item).with("Another type", "Handlebar Type")
      decorator.dl_from_attribute_othered("handlebar_type")
    end
  end

  describe 'if_present' do
    it "returns the attribute if it's present" do
      lock = Lock.new
      allow(lock).to receive(:manufacturer_other).and_return("thingsy")
      expect(ApplicationDecorator.new(lock).if_present("manufacturer_other")).to eq("thingsy")
    end
  end

  describe 'websiteable' do
    it "creates a link if bike owner wants one shown" do
      user = User.new 
      allow(user).to receive(:show_website).and_return(true)
      allow(user).to receive(:website).and_return("website")
      decorator = ApplicationDecorator.new(user).websiteable(user)
      expect(decorator).to eq('<a href="website">Website</a>')
    end
  end

  describe 'twitterable' do
    it "creates a link if bike owner wants one shown" do
      user = User.new 
      allow(user).to receive(:show_twitter).and_return(true)
      allow(user).to receive(:twitter).and_return("twitter")
      decorator = ApplicationDecorator.new(user).twitterable(user)
      expect(decorator).to eq('<a href="https://twitter.com/twitter">Twitter</a>')
    end
  end

  describe 'show_twitter_and_website' do
    it "combines twitter and website" do
      user = User.new
      decorator = ApplicationDecorator.new(user)
      allow(decorator).to receive(:twitterable).and_return("twitter")
      allow(decorator).to receive(:websiteable).and_return("website")
      expect(decorator.show_twitter_and_website(user)).to eq("twitter and website")
    end
    it "justs return website if no twitter" do
      user = User.new
      decorator = ApplicationDecorator.new(user)
      allow(decorator).to receive(:current_owner_exists).and_return(true)
      allow(decorator).to receive(:twitterable).and_return(nil)
      allow(decorator).to receive(:websiteable).and_return("website")
      expect(decorator.show_twitter_and_website(user)).to eq("website")
    end
  end

  describe 'ass_name' do
    it "grabs the association name" do
      bike = Bike.new 
      handlebar_type = FactoryGirl.create(:handlebar_type, name: "cool bars")
      allow(bike).to receive(:handlebar_type).and_return(handlebar_type)
      expect(ApplicationDecorator.new(bike).ass_name("handlebar_type")).to eq("cool bars")
    end
  end

  describe 'display_phone' do
    it "displays the phone with an area code" do
      location = Location.new 
      allow(location).to receive(:phone).and_return("999 999 9999")
      expect(ApplicationDecorator.new(location).display_phone).to eq("999 999 9999")
    end
    it "displays the phone with a country code" do
      location = Location.new 
      allow(location).to receive(:phone).and_return("+91 8041505583")
      expect(ApplicationDecorator.new(location).display_phone).to eq("+91 804 150 5583")
    end
  end

end
