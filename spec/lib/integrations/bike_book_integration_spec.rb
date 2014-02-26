require 'spec_helper'

describe BikeBookIntegration do

  describe :get_model do 
    it "should return a hash with the model for Co-motion" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: "Co-Motion")
      bike = FactoryGirl.create(:bike, manufacturer: manufacturer, frame_model: "Americano Rohloff", year: 2014)
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

end