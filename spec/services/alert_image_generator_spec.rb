require "rails_helper"

RSpec.describe AlertImageGenerator do
  describe "#bike_url" do
    it "returns a simplified url string to the given bike" do
      stolen_record = FactoryBot.create(:stolen_record)

      generator = described_class.new(stolen_record: stolen_record,
                                      bike_image: stolen_record.bike_main_image)

      bike_id = stolen_record.bike.id
      expect(generator.bike_url).to eq("bikeindex.org/bikes/#{bike_id}")
    end
  end

  describe "#bike_location" do
    context "given a stolen record location" do
      it "returns the stolen record location" do
        stolen_record = FactoryBot.create(:stolen_record)
        allow(stolen_record).to receive(:address_location).and_return("City, State")

        generator = described_class.new(stolen_record: stolen_record,
                                        bike_image: stolen_record.bike_main_image)

        expect(generator.bike_location).to eq("City, State")
      end
    end

    context "given a bike registration location" do
      it "returns registration location if stolen record location is present" do
        stolen_record = FactoryBot.create(:stolen_record)
        allow(stolen_record).to receive(:address_location).and_return("")
        bike = stolen_record.bike
        allow(bike).to receive(:registration_location).and_return("Another City, State")

        generator = described_class.new(stolen_record: stolen_record,
                                        bike_image: stolen_record.bike_main_image)

        expect(generator.bike_location).to eq("Another City, State")
      end
    end
  end
end
