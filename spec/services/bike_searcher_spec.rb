require 'spec_helper'

describe BikeSearcher do

  describe :find_bikes do 
    it "should call select manufacturers, attributes, stolen and query if stolen is present" do 
      search = BikeSearcher.new(stolen: true)
      search.should_receive(:matching_serial).and_return(Bike)
      search.should_receive(:matching_stolenness).and_return(Bike)
      search.should_receive(:matching_manufacturer).and_return(Bike)
      # search.should_receive(:matching_attr_cache).and_return(true)
      search.should_receive(:matching_query).and_return(Bike)
      search.find_bikes
    end
    it "shouldn't fail if nothing is present" do 
      search = BikeSearcher.new
      search.find_bikes.should_not be_present
    end
  end

  describe :matching_serial do 
    it "should find matching bikes" do 
      bike = FactoryGirl.create(:bike, serial_number: 'st00d-ffer')
      search = BikeSearcher.new(serial: 'STood ffer')
      search.matching_serial.first.should eq(bike)
    end
    it "should find bikes with absent serials" do 
      bike = FactoryGirl.create(:bike, serial_number: 'absent')
      search = BikeSearcher.new(serial: 'absent')
      search.matching_serial.first.should eq(bike)
    end
    it "should full text search" do 
      bike = FactoryGirl.create(:bike, serial_number: 'K10DY00047-bkd')
      search = BikeSearcher.new(serial: 'bkd-K1oDYooo47')
      search.matching_serial.first.should eq(bike)
    end
  end

  describe :matching_manufacturer do 
    it "should find matching bikes from manufacturer without id" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: 'Special bikes co.')
      bike = FactoryGirl.create(:bike, manufacturer: manufacturer)
      bike2 = FactoryGirl.create(:bike)
      search = BikeSearcher.new(manufacturer: 'Special', query: "")
      search.matching_manufacturer(Bike.scoped).first.should eq(bike)
      search.matching_manufacturer(Bike.scoped).pluck(:id).include?(bike2.id).should be_false
    end

    it "shouldn't return any bikes if we can't find the manufacturer" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: 'Special bikes co.')
      bike = FactoryGirl.create(:bike, manufacturer: manufacturer)
      search = BikeSearcher.new(manufacturer: '69696969', query: "")
      search.matching_manufacturer(Bike.scoped).count.should eq(0)
    end

    it "should find matching bikes" do 
      bike = FactoryGirl.create(:bike)
      search = BikeSearcher.new(manufacturer_id: bike.manufacturer_id, query: "something")
      search.matching_manufacturer(Bike.scoped).first.should eq(bike)
    end
  end

  describe :fuzzy_find_serial do 
    # I don't know how to test these... the test db doesn't recognize levenshtein
    xit "should find matching serial segments" do 
      bike = FactoryGirl.create(:bike, serial_number: 'st00d-fferd')
      search = BikeSearcher.new(serial: 'ffer')
      result = search.fuzzy_find_serial
      result.first.should eq(bike)
      result.count.should eq(1)
    end
    xit "shouldn't find exact matches" do 
      bike = FactoryGirl.create(:bike, serial_number: 'K10DY00047-bkd')
      search = BikeSearcher.new(serial: 'bkd-K1oDYooo47')
      search.fuzzy_find_serial.should be_nil
    end
  end

  describe :matching_stolenness do 
    before :each do 
      @non_stolen = FactoryGirl.create(:bike)
      @stolen = FactoryGirl.create(:bike, stolen: true)
    end
    it "should select only stolen bikes if non-stolen isn't selected" do 
      search = BikeSearcher.new({stolen: "on"})
      result = search.matching_stolenness(Bike.scoped)
      result.should eq([@stolen])
    end
    it "should select only non-stolen bikes if stolen isn't selected" do 
      search = BikeSearcher.new({non_stolen: "on"})
      result = search.matching_stolenness(Bike.scoped)
      result.should eq([@non_stolen])
    end
    it "should return all bikes" do 
      search = BikeSearcher.new.matching_stolenness(Bike.scoped)
      search.should eq(Bike.scoped)
    end
  end

  describe :matching_query do 
     it "should select bikes matching the attribute" do 
       search = BikeSearcher.new({query: "something"})
       bikes = Bike.scoped
       bikes.should_receive(:text_search).and_return("booger")
       search.matching_query(bikes).should eq("booger")
     end
     it "should return all bikes" do 
       search = BikeSearcher.new.matching_query(Bike.scoped)
       search.should eq(Bike.scoped)
     end
   end

end