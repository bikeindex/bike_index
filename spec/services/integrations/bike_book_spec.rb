require "rails_helper"

RSpec.describe Integrations::BikeBook do
  let(:re_record_interval) { 30.days }

  describe "get_model" do
    it "returns a hash with the model for Co-motion" do
      VCR.use_cassette("bike_book_integration-comotion", re_record_interval:) do
        manufacturer = FactoryBot.create(:manufacturer, name: "Co-Motion")
        bike = {manufacturer: manufacturer.name, frame_model: "Americano Rohloff", year: 2014}
        response = Integrations::BikeBook.new.get_model(bike)
        expect(response[:bike][:frame_model]).to eq("Americano Rohloff")
        # fork = {ctype: "fork", description: "Easton EC 90X"}
        expect(response[:components].count).to eq(8)
      end
    end

    it "returns a hash of the model for Surly" do
      VCR.use_cassette("bike_book_integration-surly", re_record_interval:) do
        manufacturer = FactoryBot.create(:manufacturer, name: "Surly")
        bike = {manufacturer: manufacturer.name, frame_model: "Pugsley", year: 2013}
        response = Integrations::BikeBook.new.get_model(bike)
        expect(response[:bike][:frame_model]).to eq("Pugsley")
        expect(response[:components].count).to eq(22)
      end
    end

    it "returns nothing if it fails" do
      VCR.use_cassette("bike_book_integration-fail", re_record_interval:) do
        manufacturer = FactoryBot.create(:manufacturer, name: "Some crazy manufacturer we have nothing on")
        bike = {manufacturer: manufacturer.name, frame_model: "Pugsley", year: 2014}
        response = Integrations::BikeBook.new.get_model(bike)
        expect(response).to be_nil
      end
    end
  end

  describe "get_model_list" do
    it "doesn't fail if bikebook is down" do
      VCR.use_cassette("bike_book_integration-models", re_record_interval:) do
        manufacturer = FactoryBot.create(:manufacturer, name: "Giant")
        all_giants = Integrations::BikeBook.new.get_model_list(manufacturer: manufacturer.name)
        expect(all_giants.is_a?(Array)).to be_truthy
        giants_from_2014 = Integrations::BikeBook.new.get_model_list({manufacturer: manufacturer.name, year: 2014})
        expect(giants_from_2014.is_a?(Array)).to be_truthy
        expect(all_giants.count).to be > giants_from_2014.count
      end
    end

    it "returns an array with the models for Giant, and a smaller array for a specific year of giant" do
      VCR.use_cassette("bike_book_integration-models-more", re_record_interval:) do
        manufacturer = FactoryBot.create(:manufacturer, name: "Giant")
        all_giants = Integrations::BikeBook.new.get_model_list(manufacturer: manufacturer.name)
        expect(all_giants.is_a?(Array)).to be_truthy
        giants_from_2014 = Integrations::BikeBook.new.get_model_list({manufacturer: manufacturer.name, year: 2014})
        expect(giants_from_2014.is_a?(Array)).to be_truthy
        expect(all_giants.count).to be > giants_from_2014.count
      end
    end

    it "returns nothing if it fails" do
      VCR.use_cassette("bike_book_integration-models-fail", re_record_interval:) do
        manufacturer = FactoryBot.create(:manufacturer, name: "Some weird manufacturer")
        response = Integrations::BikeBook.new.get_model_list(manufacturer: manufacturer.name)
        expect(response).to be_nil
      end
    end
  end
end
