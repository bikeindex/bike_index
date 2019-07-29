require "rails_helper"
require "carrierwave/test/matchers"

RSpec.describe AlertImageUploader do
  include CarrierWave::Test::Matchers

  describe "#bike_image" do
    context "given a bike with an image" do
      it "returns the public image for the stolen record's bike" do
        stolen_record = FactoryBot.create(:stolen_record)
        uploader = described_class.new(stolen_record, :theft_alert_image)
        image_path = uploader.bike_image.path
        expect(image_path).to match(/Pu\/.+\.jpg$/)
      end
    end

    context "given a bike with no image" do
      it "raises ArgumentError" do
        stolen_record = FactoryBot.create(:stolen_record, :no_image)
        uploader = described_class.new(stolen_record, :theft_alert_image)
        expect { uploader.bike_image }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#bike_url" do
    it "returns a simplified url string to the given bike" do
      stolen_record = FactoryBot.create(:stolen_record)
      uploader = described_class.new(stolen_record, :theft_alert_image)
      bike_id = stolen_record.bike.id
      expect(uploader.bike_url).to eq("bikeindex.org/bikes/#{bike_id}")
    end
  end

  describe "#bike_location" do
    context "given a bike registration address with no state" do
      it "returns an empty string" do
        stolen_record = FactoryBot.create(:stolen_record)
        uploader = described_class.new(stolen_record, :theft_alert_image)
        expect(uploader.bike_location).to eq("")
      end
    end

    context "given a bike registration address only a state" do
      it "returns the state" do
        bike = FactoryBot.create(:bike)
        allow(bike).to receive(:registration_address).and_return({ "state": "ny" })
        stolen_record = FactoryBot.create(:stolen_record, bike: bike)

        uploader = described_class.new(stolen_record, :theft_alert_image)

        expect(uploader.bike_location).to eq("NY")
      end
    end

    context "given a bike registration address with a city and state" do
      it "returns the city and state" do
        bike = FactoryBot.create(:bike)
        allow(bike).to receive(:registration_address).and_return({ "state": "ny", city: "New York" })
        stolen_record = FactoryBot.create(:stolen_record, bike: bike)

        uploader = described_class.new(stolen_record, :theft_alert_image)

        expect(uploader.bike_location).to eq("New York, NY")
      end
    end
  end

  describe "#generate_alert_image" do
    it "delegates to AlertImageGenerator" do
      stolen_record = FactoryBot.create(:stolen_record)
      uploader = described_class.new(stolen_record, :theft_alert_image)

      allow(AlertImageGenerator).to receive(:generate_image)

      uploader.generate_alert_image

      expect(AlertImageGenerator).to have_received(:generate_image)
      allow(AlertImageGenerator).to receive(:generate_image).and_call_original
    end
  end
end
