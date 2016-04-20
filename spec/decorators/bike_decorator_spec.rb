require 'spec_helper'

describe BikeDecorator do
  describe 'show_other_bikes' do
    it "links to bikes if the user is the current owner and wants to share" do
      bike = Bike.new
      user = User.new 
      allow(bike).to receive(:owner).and_return(user)
      allow(user).to receive(:show_bikes).and_return(true)
      allow(user).to receive(:username).and_return("i")
      decorator = BikeDecorator.new(bike)
      allow(bike).to receive(:current_owner_exists).and_return(true)
      expect(decorator.show_other_bikes.match("href='/users/i")).to be_present
    end
  end

  describe 'bike_show_twitter_and_website' do
    it "calls the method from application decorator" do
      user = User.new
      bike = Bike.new
      allow(bike).to receive(:owner).and_return(user)
      decorator = BikeDecorator.new(bike)
      allow(bike).to receive(:current_owner_exists).and_return(true)
      expect(decorator).to receive(:show_twitter_and_website).with(user)
      decorator.bike_show_twitter_and_website
    end
  end

  describe 'title' do
    it "returns the major bike attribs formatted" do
      bike = Bike.new
      allow(bike).to receive(:year).and_return("1999")
      allow(bike).to receive(:frame_model).and_return("model")
      allow(bike).to receive(:mnfg_name).and_return("foo")
      decorator = BikeDecorator.new(bike)
      expect(decorator.title).to eq("<span>1999 model by </span><strong>foo</strong>")
    end
  end

  describe 'phoneable_by' do
    it "does not return anything if there isn't a stolen record" do
      bike = Bike.new
      expect(BikeDecorator.new(bike).phoneable_by).to be_nil
    end
    it "returns true if users can see it" do
      bike = Bike.new 
      stolen_record = StolenRecord.new
      allow(bike).to receive(:stolen).and_return(true)
      allow(bike).to receive(:current_stolen_record).and_return(stolen_record)
      allow(stolen_record).to receive(:phone_for_everyone).and_return(true)
      expect(BikeDecorator.new(bike).phoneable_by).to be_truthy
    end

    it "returns true if users can see it and user is there" do
      user = User.new
      bike = Bike.new 
      stolen_record = StolenRecord.new
      allow(bike).to receive(:stolen).and_return(true)
      allow(bike).to receive(:current_stolen_record).and_return(stolen_record)
      allow(stolen_record).to receive(:phone_for_users).and_return(true)
      expect(BikeDecorator.new(bike).phoneable_by(user)).to be_truthy
    end

    it "returns true if shops can see it and user has shop membership" do
      user = User.new
      bike = Bike.new 
      stolen_record = StolenRecord.new
      allow(user).to receive(:has_shop_membership?).and_return(true)
      allow(bike).to receive(:stolen).and_return(true)
      allow(bike).to receive(:current_stolen_record).and_return(stolen_record)
      allow(stolen_record).to receive(:phone_for_users).and_return(false)
      allow(stolen_record).to receive(:phone_for_shops).and_return(true)
      expect(BikeDecorator.new(bike).phoneable_by(user)).to be_truthy
    end

    it "returns true if police can see it and user is police" do
      user = User.new
      bike = Bike.new 
      stolen_record = StolenRecord.new
      allow(user).to receive(:has_police_membership?).and_return(true)
      allow(bike).to receive(:stolen).and_return(true)
      allow(bike).to receive(:current_stolen_record).and_return(stolen_record)
      allow(stolen_record).to receive(:phone_for_users).and_return(false)
      allow(stolen_record).to receive(:phone_for_shops).and_return(false)
      allow(stolen_record).to receive(:phone_for_police).and_return(true)
      expect(BikeDecorator.new(bike).phoneable_by(user)).to be_truthy
    end

    it "returns true for superusers" do
      user = User.new
      bike = Bike.new 
      stolen_record = StolenRecord.new
      allow(user).to receive(:superuser).and_return(true)
      allow(bike).to receive(:stolen).and_return(true)
      allow(bike).to receive(:current_stolen_record).and_return(stolen_record)
      allow(stolen_record).to receive(:phone_for_users).and_return(false)
      allow(stolen_record).to receive(:phone_for_shops).and_return(false)
      allow(stolen_record).to receive(:phone_for_police).and_return(false)
      expect(BikeDecorator.new(bike).phoneable_by(user)).to be_truthy
    end
  end

  describe 'tire_width' do
    it "returns wide if false" do
      bike = Bike.new
      allow(bike).to receive(:front_tire_narrow).and_return(nil)
      decorator = BikeDecorator.new(bike).tire_width("front")
      expect(decorator).to eq("wide")
    end
    it "returns narrow if narrow" do
      bike = Bike.new
      allow(bike).to receive(:rear_tire_narrow).and_return(true)
      decorator = BikeDecorator.new(bike).tire_width("rear")
      expect(decorator).to eq("narrow")
    end
  end

  describe 'list_link_url' do
    it "returns the bike edit path if edit" do
      bike = Bike.new 
      allow(bike).to receive(:id).and_return(69)
      decorator = BikeDecorator.new(bike).list_link_url("edit")
      expect(decorator).to eq("/bikes/69/edit")
    end

    it "returns the normal path if passed" do
      bike = Bike.new 
      allow(bike).to receive(:id).and_return(69)
      decorator = BikeDecorator.new(bike).list_link_url()
      expect(decorator).to eq("/bikes/69")
    end
  end

  describe 'thumb_image' do
    it "returns the thumb path if one exists" do
      bike = Bike.new
      allow(bike).to receive(:thumb_path).and_return("pathy")
      decorator = BikeDecorator.new(bike)
      allow(decorator).to receive(:title_string).and_return("Title")
      expect(decorator.thumb_image).to eq("<img alt=\"Title\" src=\"/assets/pathy\" />")
    end
  end

  describe 'list_image' do
    it "returns the link with  thumb path if nothing is passed" do
      bike = Bike.new
      allow(bike).to receive(:id).and_return(69)
      decorator = BikeDecorator.new(bike)
      allow(decorator).to receive(:thumb_image).and_return("imagey")
      expect(decorator.list_image).not_to be_nil
    end
    it "returns the images thumb path" do
      bike = Bike.new
      allow(bike).to receive(:id).and_return(69)
      allow(bike).to receive(:thumb_path).and_return("something")
      decorator = BikeDecorator.new(bike)
      allow(decorator).to receive(:thumb_image).and_return("imagey")
      expect(decorator.list_image).not_to be_nil
    end
  end

  describe 'serial_display' do
    it "returns do not know if stolen" do
      bike = Bike.new(serial_number: 'absent')
      allow(bike).to receive(:stolen).and_return(true)
      decorator = BikeDecorator.new(bike)
      expect(decorator.serial_display).to eq('Do not know')
    end

    it "returns has no serial if not stolen" do
      bike = Bike.new(serial_number: 'absent')
      allow(bike).to receive(:stolen).and_return(false)
      decorator = BikeDecorator.new(bike)
      expect(decorator.serial_display).to eq('Has no serial')
    end
    it "returns hidden if recovered" do   
      bike = Bike.new(serial_number: 'asdf')
      allow(bike).to receive(:stolen).and_return(false)
      allow(bike).to receive(:recovered).and_return(true)
      decorator = BikeDecorator.new(bike)
      expect(decorator.serial_display).to eq('Hidden')
    end

    it "returns serial number" do
      bike = Bike.new(serial_number: 'test_serial')
      allow(bike).to receive(:stolen).and_return(false)
      allow(bike).to receive(:recovered).and_return(false)
      decorator = BikeDecorator.new(bike)
      expect(decorator.serial_display).to eq('test_serial')
    end
  end

end
