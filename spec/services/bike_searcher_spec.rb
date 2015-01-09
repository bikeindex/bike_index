require 'spec_helper'

describe BikeSearcher do

  describe :find_bikes do 
    it "calls select manufacturers, attributes, stolen and query if stolen is present" do 
      search = BikeSearcher.new(stolen: true)
      search.should_receive(:matching_serial).and_return(Bike)
      search.should_receive(:matching_stolenness).and_return(Bike)
      search.should_receive(:matching_manufacturer).and_return(Bike)
      # search.should_receive(:matching_attr_cache).and_return(true)
      search.should_receive(:matching_query).and_return(Bike)
      search.find_bikes
    end
    it "does not fail if nothing is present" do 
      search = BikeSearcher.new
      search.find_bikes.should_not be_present
    end
  end

  describe :matching_serial do 
    it "finds matching bikes" do 
      bike = FactoryGirl.create(:bike, serial_number: 'st00d-ffer')
      search = BikeSearcher.new(serial: 'STood ffer')
      search.matching_serial.first.should eq(bike)
    end
    it "finds bikes with absent serials" do 
      bike = FactoryGirl.create(:bike, serial_number: 'absent')
      search = BikeSearcher.new(serial: 'absent')
      search.matching_serial.first.should eq(bike)
    end
    it "fulls text search" do 
      bike = FactoryGirl.create(:bike, serial_number: 'K10DY00047-bkd')
      search = BikeSearcher.new(serial: 'bkd-K1oDYooo47')
      search.matching_serial.first.should eq(bike)
    end
  end

  describe :matching_manufacturer do 
    it "finds matching bikes from manufacturer without id" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: 'Special bikes co.')
      bike = FactoryGirl.create(:bike, manufacturer: manufacturer)
      bike2 = FactoryGirl.create(:bike)
      search = BikeSearcher.new(manufacturer: 'Special', query: "")
      search.matching_manufacturer(Bike.scoped).first.should eq(bike)
      search.matching_manufacturer(Bike.scoped).pluck(:id).include?(bike2.id).should be_false
    end

    it "does not return any bikes if we can't find the manufacturer" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: 'Special bikes co.')
      bike = FactoryGirl.create(:bike, manufacturer: manufacturer)
      search = BikeSearcher.new(manufacturer: '69696969', query: "")
      search.matching_manufacturer(Bike.scoped).count.should eq(0)
    end

    it "finds matching bikes" do 
      bike = FactoryGirl.create(:bike)
      search = BikeSearcher.new(manufacturer_id: bike.manufacturer_id, query: "something")
      search.matching_manufacturer(Bike.scoped).first.should eq(bike)
    end
  end

  describe 'matching_colors' do 
    it "finds matching colors" do
      color = FactoryGirl.create(:color)
      bike = FactoryGirl.create(:bike, tertiary_frame_color_id: color.id)
      FactoryGirl.create(:bike)
      search = BikeSearcher.new({colors: "something, #{color.name}"}).matching_colors(Bike.scoped)
      search.count.should eq(1)
      search.first.should eq(bike)
    end
  end

  describe :fuzzy_find_serial do 
    # If these specs are failing and saying things about LEVENSHTEIN not existing
    # You need to install fuzzystrmatch in your test db. Read README for more info
    xit "should find matching serial segments" do 
      bike = FactoryGirl.create(:bike, serial_number: 'st00d-fferd')
      SerialNormalizer.new({serial: bike.serial_number}).save_segments(bike.id)
      search = BikeSearcher.new(serial: 'fferds')
      result = search.fuzzy_find_serial
      result.first.should eq(bike)
      result.count.should eq(1)
    end
    xit "shouldn't find exact matches" do 
      bike = FactoryGirl.create(:bike, serial_number: 'K10DY00047-bkd')
      search = BikeSearcher.new(serial: 'bkd-K1oDYooo47')
      search.fuzzy_find_serial.should be_empty
    end
  end

  describe :matching_stolenness do 
    before :each do 
      @non_stolen = FactoryGirl.create(:bike)
      @stolen = FactoryGirl.create(:bike, stolen: true)
    end
    it "selects only stolen bikes if non-stolen isn't selected" do 
      search = BikeSearcher.new({stolen: "on"})
      result = search.matching_stolenness(Bike.scoped)
      result.should eq([@stolen])
    end
    it "selects only non-stolen bikes if stolen isn't selected" do 
      search = BikeSearcher.new({non_stolen: "on"})
      result = search.matching_stolenness(Bike.scoped)
      result.should eq([@non_stolen])
    end
    it "returns all bikes" do 
      search = BikeSearcher.new.matching_stolenness(Bike.scoped)
      search.should eq(Bike.scoped)
    end
  end

  describe :matching_query do 
     it "selects bikes matching the attribute" do 
       search = BikeSearcher.new({query: "something"})
       bikes = Bike.scoped
       bikes.should_receive(:text_search).and_return("booger")
       search.matching_query(bikes).should eq("booger")
     end
   end

end
