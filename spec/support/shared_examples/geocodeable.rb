require "rails_helper"

RSpec.shared_examples "geocodeable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create model_sym }

  describe "friendly assigning state and country" do
    let(:country) { Country.united_states }
    let!(:state) { State.create(name: "Wyoming", abbreviation: "WY", country_id: country.id) }
    let(:obj_with_strings) { subject.class.new(state: "wy", country: "USA") }
    let(:obj_with_objects) { subject.class.new(state: state, country_id: country.id) }
    it "assigns by strings and by object, doesn't explode when not found" do
      expect(obj_with_strings.country).to eq country
      expect(obj_with_strings.state).to eq state
      obj_with_strings.state = "wyoming"
      expect(obj_with_strings.state).to eq state

      expect(obj_with_objects.country).to eq country
      expect(obj_with_objects.state).to eq state
      # Doesn't explode when not found
      obj_with_objects.state = "Other state"
      expect(obj_with_objects.state).to be_blank
    end
  end

  describe ".address" do
    let(:object) do
      FactoryBot.build_stubbed(
        model_sym,
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
        expect(object.address_present?).to be_truthy
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
        expect(object.address_present?).to be_truthy
      end

      it "returns an address with no country if country is optional" do
        object.country = nil
        addr = Geocodeable.address(object, country: [:optional])
        expect(addr).to eq("1 Park Ave., New York, NY 10016")
        expect(object.address_present?).to be_truthy
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
        expect(object.address_present?).to be_truthy
      end
    end
  end

  describe ".address_present" do
    context "country and state" do
      let(:state) { FactoryBot.create(:state_new_york) }
      let(:object) { subject.class.new(country: Country.united_states, state: state) }
      it "is falsey" do
        expect(object.address_present?).to be_falsey
      end
    end
    context "zipcode" do
      let(:object) { subject.class.new(zipcode: "94608") }
      it "is truthy" do
        expect(object.address_present?).to be_truthy
      end
    end
    context "city" do
      let(:object) { subject.class.new(city: "Oakland") }
      it "is truthy" do
        expect(object.address_present?).to be_truthy
      end
    end
    context "zipcode" do
      let(:object) { subject.class.new(street: "123 Main St") }
      it "is truthy" do
        expect(object.address_present?).to be_truthy
      end
    end
  end
end
