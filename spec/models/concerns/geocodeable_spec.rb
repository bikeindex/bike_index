# frozen_string_literal: true

require "rails_helper"

RSpec.describe Geocodeable, type: :model do
  describe ".address" do
    let(:object) do
      FactoryBot.build_stubbed(
        :stolen_record,
        street: "1 Park Ave.",
        city: "New York",
        state: FactoryBot.build_stubbed(:state_new_york),
        zipcode: "10016",
        country: FactoryBot.build_stubbed(:country_us)
      )
    end
    context "given booleans for address components" do
      it "toggles component inclusion in the address string" do
        addr = Geocodeable.address(object)
        expect(addr).to eq("1 Park Ave., New York, NY 10016, US")
        addr = Geocodeable.address(object, street: false)
        expect(addr).to eq("New York, NY 10016, US")
        addr = Geocodeable.address(object, city: false)
        expect(addr).to eq("1 Park Ave., NY 10016, US")
        addr = Geocodeable.address(object, zipcode: false)
        expect(addr).to eq("1 Park Ave., New York, NY, US")
        addr = Geocodeable.address(object, country: false)
        expect(addr).to eq("1 Park Ave., New York, NY 10016")
      end
    end

    context "given a format option for country" do
      it "toggles country format" do
        addr = Geocodeable.address(object, country: [:iso])
        expect(addr).to eq("1 Park Ave., New York, NY 10016, US")
        addr = Geocodeable.address(object, country: [:name])
        expect(addr).to eq("1 Park Ave., New York, NY 10016, United States")
      end
    end

    context "given no country data" do
      it "returns nothing by default since country is required" do
        object.country = nil
        addr = Geocodeable.address(object)
        expect(addr).to eq("")
      end

      it "returns an address with no country if country is optional" do
        object.country = nil
        addr = Geocodeable.address(object, country: [:optional])
        expect(addr).to eq("1 Park Ave., New York, NY 10016")
      end
    end

    context "given the :skip_default option for country" do
      it "omits the country if the US, else includes it" do
        expect(object.country).to be_default

        addr = Geocodeable.address(object, country: [:iso, :skip_default])
        expect(addr).to eq("1 Park Ave., New York, NY 10016")

        object.country = Country.canada

        addr = Geocodeable.address(object, country: [:skip_default])
        expect(addr).to eq("1 Park Ave., New York, NY 10016, CA")

        addr = Geocodeable.address(object, country: [:name, :skip_default])
        expect(addr).to eq("1 Park Ave., New York, NY 10016, Canada")
      end
    end
  end
end
