require 'spec_helper'

describe BikeSearcher do

  describe :find_bikes do 
    it "should call select manufacturers, attributes, stolen and query" do 
      search = BikeSearcher.new
      search.should_receive(:matching_stolenness).and_return(true)
      search.should_receive(:matching_manufacturers).and_return(true)
      search.should_receive(:matching_attr_cache).and_return(true)
      search.should_receive(:matching_query).and_return(true)
      search.find_bikes
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

  describe :matching_manufacturers do 
    before :each do 
      @bike1 = FactoryGirl.create(:bike)
      @bike2 = FactoryGirl.create(:bike)
    end
    it "should select bikes matching the manufacturer" do 
      search = BikeSearcher.new()
      search.stub(:parsed_manufacturer_ids).and_return(@bike1.manufacturer_id)
      result = search.matching_manufacturers(Bike.scoped)
      result.should eq([@bike1])
    end
    it "should select bikes matching multiple manufacturers" do
      FactoryGirl.create(:bike)
      search = BikeSearcher.new()
      mnfgs = [@bike1.manufacturer_id, @bike2.manufacturer_id]
      search.stub(:parsed_manufacturer_ids).and_return(mnfgs)
      result = search.matching_manufacturers(Bike.scoped)
      result.should eq([@bike2, @bike1])
    end
    it "should return all bikes" do 
      search = BikeSearcher.new.matching_manufacturers(Bike.scoped)
      search.should eq(Bike.scoped)
    end
  end

  describe :parsed_manufacturer_ids do 
    it "should grab the numbers that it needs to grab" do 
      search = BikeSearcher.new({:find_manufacturers => { :ids => ["", "9", "16", "3"] } })
      result = search.parsed_manufacturer_ids
      result.should eq([9,16,3])      
    end
  end

  describe :matching_attr_cache do 
     before :each do 
       @bike1 = FactoryGirl.create(:bike)
       @bike2 = FactoryGirl.create(:bike)
       @bike3 = FactoryGirl.create(:bike, primary_frame_color_id: @bike1.primary_frame_color_id, secondary_frame_color_id: @bike2.primary_frame_color_id)
     end
     it "should select bikes matching the attribute" do 
       search = BikeSearcher.new({bike_attribute_ids: "present"})
       search.stub(:parsed_attributes).and_return(["1c#{@bike1.primary_frame_color_id}"])
       result = search.matching_attr_cache(Bike.scoped)
       result.first.should eq(@bike3)
       result.last.should eq(@bike1)
       result.count.should eq(2)
       result.class.should eq(ActiveRecord::Relation)
     end
     it "should return all bikes" do 
       search = BikeSearcher.new.matching_attr_cache(Bike.scoped)
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