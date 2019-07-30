require "rails_helper"
require "carrierwave/test/matchers"

RSpec.describe AlertImageUploader do
  include CarrierWave::Test::Matchers

  describe "#bike_url" do
    it "returns a simplified url string to the given bike" do
      stolen_record = FactoryBot.create(:stolen_record)
      uploader = described_class.new(stolen_record, :theft_alert_image)
      bike_id = stolen_record.bike.id
      expect(uploader.bike_url).to eq("bikeindex.org/bikes/#{bike_id}")
    end
  end

  describe "#bike_location" do
    context "given a stolen record location" do
      it "returns the stolen record location" do
        stolen_record = FactoryBot.create(:stolen_record)
        allow(stolen_record).to receive(:location).and_return("City, State")
        uploader = described_class.new(stolen_record, :theft_alert_image)
        expect(uploader.bike_location).to eq("City, State")
      end
    end

    context "given a bike registration location" do
      it "returns registration location if stolen record location is present" do
        stolen_record = FactoryBot.create(:stolen_record)
        allow(stolen_record).to receive(:location).and_return("")
        bike = stolen_record.bike
        allow(bike).to receive(:registration_location).and_return("Another City, State")
        uploader = described_class.new(stolen_record, :theft_alert_image)
        expect(uploader.bike_location).to eq("Another City, State")
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
