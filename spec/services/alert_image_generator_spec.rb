require "rails_helper"

RSpec.describe AlertImageGenerator do
  describe "#bike_url" do
    context "given a bike id" do
      it "returns a simplified url string to the given bike" do
        stolen_record = FactoryBot.create(:stolen_record)
        generator = described_class.new(stolen_record: stolen_record, bike_image: nil)
        expect(generator.bike_url).to eq("bikeindex.org/bikes/#{stolen_record.bike.id}")
      end
    end

    context "given no bike id" do
      it "returns a simplified url string to the given bike" do
        stolen_record = FactoryBot.create(:stolen_record)
        stolen_record.update_attribute(:bike, nil)
        generator = described_class.new(stolen_record: stolen_record, bike_image: nil)
        expect(generator.bike_url).to be_nil
      end
    end
  end

  describe "#stolen_record_location" do
    let(:generator) { described_class.new(stolen_record: stolen_record, bike_image: nil) }
    let(:state) { FactoryBot.create(:state_california) }
    let(:location_attrs) { { state: state, country: Country.united_states, street: "100 W 1st St", city: "Los Angeles", zipcode: "90021", latitude: 34.05223, longitude: -118.24368 } }
    context "stolen record with a location" do
      let(:stolen_record) { StolenRecord.new(location_attrs) }
      it "returns the stolen record location" do
        expect(stolen_record.to_coordinates).to eq([location_attrs[:latitude], location_attrs[:longitude]])
        expect(generator.stolen_record_location).to eq("Los Angeles, CA")
      end
    end
    context "stolen_record without street, zipcode or city" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, *location_attrs.slice(:country, :state, :latitude, :longitude)) }
      it "returns without" do
        stolen_record.reload
        expect(stolen_record.to_coordinates).to eq([])
        expect(generator.stolen_record_location).to be_blank
      end
    end
    context "Edmonton" do
      let(:location_attrs) { { street: "7935 Gateway Blvd", city: "Edmonton", zipcode: "T6E 3X8", latitude: 53.515072, longitude: -113.494412, state: nil, country: Country.canada } }
      let(:stolen_record) { FactoryBot.create(:stolen_record, *location_attrs) }
      it "returns edmonton" do
        stolen_record.reload
        expect(stolen_record.to_coordinates).to eq([location_attrs[:latitude], location_attrs[:longitude]])
        expect(generator.stolen_record_location).to eq("Edmonton, Canada")
      end
    end
  end
end
