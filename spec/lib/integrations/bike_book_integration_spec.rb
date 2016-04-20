require 'spec_helper'

describe BikeBookIntegration do
  describe 'get_model' do
    it "returns a hash with the model for Co-motion" do
      manufacturer = FactoryGirl.create(:manufacturer, name: "Co-Motion")
      bike = {manufacturer: manufacturer.name, frame_model: "Americano Rohloff", year: 2014}
      response = BikeBookIntegration.new.get_model(bike)
      expect(response[:bike][:frame_model]).to eq('Americano Rohloff')
      fork = { ctype: "fork", description: "Easton EC 90X"}
      expect(response[:components].count).to eq(8)
    end

    it "returns a hash of the model for Surly" do
      manufacturer = FactoryGirl.create(:manufacturer, name: "Surly")
      bike = {manufacturer: manufacturer.name, frame_model: "Pugsley", year: 2013}
      response = BikeBookIntegration.new.get_model(bike)
      expect(response[:bike][:frame_model]).to eq('Pugsley')
      expect(response[:components].count).to eq(22)
    end

    it "returns nothing if it fails" do
      manufacturer = FactoryGirl.create(:manufacturer, name: "Some crazy manufacturer we have nothing on")
      bike = { manufacturer: manufacturer.name, frame_model: "Pugsley", year: 2014 }
      response = BikeBookIntegration.new.get_model(bike)
      expect(response).to be_nil
    end
  end

  describe 'get_model_list' do
    it "doesn't fail if bikebook is down" do
      manufacturer = FactoryGirl.create(:manufacturer, name: "Giant")
      all_giants = BikeBookIntegration.new.get_model_list({manufacturer: manufacturer.name})
      expect(all_giants.kind_of?(Array)).to be_truthy
      giants_from_2014 = BikeBookIntegration.new.get_model_list({manufacturer: manufacturer.name, year: 2014})
      expect(giants_from_2014.kind_of?(Array)).to be_truthy
      expect(all_giants.count).to be > giants_from_2014.count
    end
    
    it "returns an array with the models for Giant, and a smaller array for a specific year of giant" do
      manufacturer = FactoryGirl.create(:manufacturer, name: "Giant")
      all_giants = BikeBookIntegration.new.get_model_list({manufacturer: manufacturer.name})
      expect(all_giants.kind_of?(Array)).to be_truthy
      giants_from_2014 = BikeBookIntegration.new.get_model_list({manufacturer: manufacturer.name, year: 2014})
      expect(giants_from_2014.kind_of?(Array)).to be_truthy
      expect(all_giants.count).to be > giants_from_2014.count
    end

    it "returns nothing if it fails" do
      manufacturer = FactoryGirl.create(:manufacturer, name: "Some weird manufacturer")
      response = BikeBookIntegration.new.get_model_list({manufacturer: manufacturer.name})
      expect(response).to be_nil
    end
  end

end
