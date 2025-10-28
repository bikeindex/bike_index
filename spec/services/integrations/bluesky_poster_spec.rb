require "rails_helper"

RSpec.describe Integrations::BlueskyPoster do
  let(:stolen_record) { bike.fetch_current_stolen_record if defined?(bike) }
  before do
    # reverse geocode bike stolen records
    stolen_record&.skip_geocoding = false
    stolen_record&.save
  end

  describe "#build_bike_status" do
    context "stolen bike" do
      let!(:national_account) { FactoryBot.create(:twitter_account_1, :active, :national) }
      let(:bike) { FactoryBot.create(:stolen_bike, :blue_trek_930) }
      let(:bpi) { Integrations::BlueskyPoster.new(bike) }
      before do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")
      end
      let(:target) { "STOLEN - Blue Trek 930 in New York https://bikeindex.org/bikes/#{bike.id}" }
      it "creates correct string without media" do
        expect(bpi.build_bike_status).to eq target
      end

      context "with manufacturer other" do
        let(:manufacturer_other) { "Really cool manufacturer name" }
        let(:color) { FactoryBot.create(:color, name: "Silver, gray or bare metal") }
        let(:bike) do
          FactoryBot.create(:stolen_bike,
            primary_frame_color: color,
            secondary_frame_color: Color.black,
            manufacturer: Manufacturer.other,
            manufacturer_other: manufacturer_other,
            frame_model: "Bike lyfe")
        end
        let(:target) { "STOLEN - Gray #{manufacturer_other} Bike lyfe in New York https://bikeindex.org/bikes/#{bike.id}" }
        it "does the long manufacturer" do
          expect(bpi.build_bike_status).to eq target
        end
      end

      context "Yellow" do
        let(:color) { FactoryBot.create(:color, name: "Yellow or Gold") }
        let(:manufacturer) { FactoryBot.create(:manufacturer, name: "BH Bikes (Beistegui Hermanos)") }
        let(:bike) { FactoryBot.create(:stolen_bike, manufacturer:, primary_frame_color: color, frame_model: "ATOMX CARBON LYNX 5.5 PRO") }
        let(:target) { "STOLEN - Yellow BH Bikes ATOMX CARBON LYNX 5.5 PRO in New York https://bikeindex.org/bikes/#{bike.id}" }
        it "simplifies color" do
          expect(bpi.build_bike_status).to eq target
        end
      end

      context "with append_block" do
        before { national_account.update(append_block: "#bikeParty") }
        let(:target) { "STOLEN - Blue Trek 930 in New York https://bikeindex.org/bikes/#{bike.id} #bikeParty" }
        it "creates correct string with append block" do
          expect(bpi.build_bike_status).to eq target
        end

        context "long string" do
          # post without append block is 80 characters - so frame model needs to be >
          # POST_LENGTH - 80 - 10 (#bikeParty) = 210
          let(:color) { FactoryBot.create(:color, name: "Stickers tape or other cover-up") }
          let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Salsa") }
          let(:bike) { FactoryBot.create(:stolen_bike, manufacturer:, primary_frame_color: color, frame_model: long_string) }
          let(:long_string) { "Large and sweet MTB, a much longer frame model, because someone put a very long string in here that meanders back and forth and eventually comes to some sort of conclusion but not really! It keeps going and going" }
          let(:target) { "STOLEN - Stickers Salsa #{long_string} in New York https://bikeindex.org/bikes/#{bike.id}" }
          it "creates correct string without append block if string is too long" do
            expect(bpi.build_bike_status).to eq target
          end
        end
      end
    end

    context "bike with image" do
      let!(:national_account) { FactoryBot.create(:twitter_account_1, :active, :national) }
      let(:bike) { FactoryBot.create(:stolen_bike, :blue_trek_930, :with_image) }

      it "creates correct string with media" do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")

        bpi = Integrations::BlueskyPoster.new(bike)

        expect(bpi.build_bike_status).to(eq <<~STR.strip)
          STOLEN - Blue Trek 930 in New York https://bikeindex.org/bikes/#{bike.id}
        STR
      end
    end
  end

  describe "#initialize" do
    let!(:national_account) { FactoryBot.create(:twitter_account_1, :active, :national) }
    let(:bike) { FactoryBot.create(:stolen_bike, :blue_trek_930) }
    let(:bpi) { Integrations::BlueskyPoster.new(bike) }

    it "sets attributes correctly" do
      expect(bpi.bike).to eq bike
      expect(bpi.stolen_record).to eq bike.current_stolen_record
      expect(bpi.national_twitter_account).to eq national_account
    end
  end

  describe "#stolen_slug" do
    let!(:national_account) { FactoryBot.create(:twitter_account_1, :active, :national) }

    context "stolen bike" do
      let(:bike) { FactoryBot.create(:stolen_bike) }
      let(:bpi) { Integrations::BlueskyPoster.new(bike) }

      it "returns STOLEN -" do
        expect(bpi.stolen_slug).to eq "STOLEN -"
      end
    end

    context "found bike" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, status: "status_with_owner") }
      let(:bpi) { Integrations::BlueskyPoster.new(bike) }

      it "returns FOUND -" do
        expect(bpi.stolen_slug).to eq "FOUND -"
      end
    end
  end

  describe "#compute_max_char" do
    let!(:national_account) { FactoryBot.create(:twitter_account_1, :active, :national) }
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:bpi) { Integrations::BlueskyPoster.new(bike) }

    it "computes max char correctly" do
      # POST_LENGTH (300) - https_length (23) - stolen_slug (8 chars: "STOLEN -") - 2 spaces
      expect(bpi.compute_max_char).to eq 267
    end
  end
end
