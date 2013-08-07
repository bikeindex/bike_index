require 'spec_helper'

describe SearchBikes do
  describe :search_type do 
    it "returns a object describing the search" do
      SearchBikes.new().search_type[:most_recent].should be_true
      SearchBikes.new().search_type[:phrase].should eq("bikes")
      SearchBikes.new({query: "", search_stolen: ["true"]}).search_type[:phrase].should eq('stolen bikes')
      SearchBikes.new({search_stolen: ["false"]}).search_type[:phrase].should eq('non-stolen bikes')
      SearchBikes.new({search_stolen: ["false"]}).search_type[:most_recent].should be_true
      SearchBikes.new({query: "anything"}).search_type[:phrase].should eq('bikes')
      SearchBikes.new({query: "anything"}).search_type[:most_recent].should be_false
    end
  end
  
  describe :bikes do 
    before :each do 
      @stolen_bike = FactoryGirl.create(:bike, stolen: true)
      @non_stolen_bike = FactoryGirl.create(:bike, stolen: false)
      @serialed_bike = FactoryGirl.create(:bike, stolen: false, serial_number: "abcde")
    end

    it "should return bikes in descending order if there are no params" do
      SearchBikes.new().bikes.first.should eq(@serialed_bike)
      SearchBikes.new().bikes.second.should eq(@non_stolen_bike)
    end

    it "should return bikes in descending order if no query is present" do
      params = {}
      search = SearchBikes.new(params).bikes
      search.first.should eq(@serialed_bike)
      search.second.should eq(@non_stolen_bike)
      search.third.should eq(@stolen_bike)
    end

    it "should return only stolen bikes if stolen is true" do
      params = {query: "", search_stolen: ["true"]}
      SearchBikes.new(params).bikes.first.should eq(@stolen_bike)
    end

    it "should return only non-stolen bikes if stolen is false" do
      params = {query: "", search_stolen: ["false"]}
      search = SearchBikes.new(params).bikes
      search.first.should eq(@serialed_bike)
      search.second.should eq(@non_stolen_bike)
    end

    it "should return the bike that matches the query" do 
      params = {query: "abcde"}
      SearchBikes.new(params).bikes.first.should eq(@serialed_bike)
    end

    it "should return only stolen bikes that match the query if stolen is true" do
      params = {query: "abcde", search_stolen: ["true"]}
      SearchBikes.new(params).bikes.should be_empty
    end

    it "should return only non-stolen bikes that match the query if stolen is false" do
      params = {query: "abcde", search_stolen: ["false"]}
      SearchBikes.new(params).bikes.first.should eq(@serialed_bike)
    end
  end

end
