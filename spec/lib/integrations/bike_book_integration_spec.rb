require 'spec_helper'

describe BikeBookIntegration do

  describe :get_model do 
    it "should return a hash with the model for Co-motion" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: "Co-Motion")
      bike = {manufacturer: manufacturer, frame_model: "Americano Rohloff", year: 2014}
      response = BikeBookIntegration.new.get_model(bike)
      response[:bike][:frame_model].should eq('Americano Rohloff')
      fork = { ctype: "fork", description: "Easton EC 90X"}
      response[:components].count.should eq(8)
    end

    it "should return a hash of the model for Surly" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: "Surly")
      bike = FactoryGirl.create(:bike, manufacturer: manufacturer, frame_model: "Pugsley", year: 2014)
      response = BikeBookIntegration.new.get_model(bike)
      response[:bike][:frame_model].should eq('Pugsley')
      response[:components].count.should eq(22)
    end

    it "should return nothing if it fails" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: "Some crazy manufacturer we have nothing on")
      bike = FactoryGirl.create(:bike, manufacturer: manufacturer, frame_model: "Pugsley", year: 2014)
      response = BikeBookIntegration.new.get_model(bike)
      response.should be_nil
    end
  end

  describe :get_model_list do 
    it "should return an array with the models for Giant, and a smaller array for a specific year of giant" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: "Giant")
      all_giants = BikeBookIntegration.new.get_model_list({manufacturer: manufacturer.name})
      all_giants.kind_of?(Array).should be_true
      giants_from_2014 = BikeBookIntegration.new.get_model_list({manufacturer: manufacturer.name, year: 2014})
      giants_from_2014.kind_of?(Array).should be_true
      all_giants.count.should > giants_from_2014.count
    end

    it "should return nothing if it fails" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: "Some weird manufacturer")
      response = BikeBookIntegration.new.get_model_list({manufacturer: manufacturer.name})
      response.should be_nil
    end
  end

end