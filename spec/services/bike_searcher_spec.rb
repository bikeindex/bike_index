require 'spec_helper'

describe BikeSearcher do

  describe :find_bikes do 
    it "should call select manufacturers, attributes, stolen and query" do 
      search = BikeSearcher.new
      search.should_receive(:matching_serial).and_return(true)
      search.should_receive(:matching_stolenness).and_return(true)
      # search.should_receive(:matching_manufacturers).and_return(true)
      # search.should_receive(:matching_attr_cache).and_return(true)
      search.should_receive(:matching_query).and_return(true)
      search.find_bikes
    end
  end

  describe :matching_serial do 
    it "should find matching bikes" do 
      bike = FactoryGirl.create(:bike, serial_number: 'st00d-ffer')
      search = BikeSearcher.new(serial: 'STood ffer')
      search.matching_serial.first.should eq(bike)
    end
    it "should find matching bikes" do 
      bike = FactoryGirl.create(:bike, serial_number: 'absent')
      search = BikeSearcher.new(serial: 'absent')
      search.matching_serial.first.should eq(bike)
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