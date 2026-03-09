require "rails_helper"

RSpec.shared_examples "geocodeable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create model_sym }

  describe "friendly assigning region_record and country" do
    let(:country) { Country.united_states }
    let!(:state) { State.create(name: "Wyoming", abbreviation: "WY", country_id: country.id) }
    let(:obj_with_strings) { subject.class.new(region_record: "wy", country: "USA") }
    let(:obj_with_objects) { subject.class.new(region_record: state, country_id: country.id) }
    it "assigns by strings and by object, doesn't explode when not found" do
      expect(obj_with_strings.country).to eq country
      expect(obj_with_strings.region_record).to eq state
      obj_with_strings.region_record = "wyoming"
      expect(obj_with_strings.region_record).to eq state
      expect(obj_with_strings.metric_units?).to be_falsey # Because US

      expect(obj_with_objects.country).to eq country
      expect(obj_with_objects.region_record).to eq state
      # Doesn't explode when not found
      obj_with_objects.region_record = "Other state"
      expect(obj_with_objects.region_record).to be_blank
    end
  end

  describe ".address" do
    let(:object) do
      FactoryBot.build_stubbed(
        model_sym,
        street: "1 Park Ave.",
        city: "New York",
        region_record: FactoryBot.build_stubbed(:state_new_york),
        postal_code: "10016",
        country: FactoryBot.build_stubbed(:country_united_states)
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
        addr = Geocodeable.address(object, postal_code: false)
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
        expect(object.metric_units?).to be_truthy # Default to metric, because it's better
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
    context "country and region_record" do
      let(:state) { FactoryBot.create(:state_new_york) }
      let(:object) { subject.class.new(country: Country.united_states, region_record: state) }
      it "is falsey" do
        expect(object.address_present?).to be_falsey
      end
    end
    context "postal_code" do
      let(:object) { subject.class.new(postal_code: "94608") }
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
    context "street" do
      let(:object) { subject.class.new(street: "123 Main St") }
      it "is truthy" do
        expect(object.address_present?).to be_truthy
      end
    end
  end

  describe ".clean_region_and_street_data" do
    let!(:state) { nil }
    let(:object) { subject.class.new(street: " ", city: "\n", postal_code: "   ") }
    before { object.clean_region_and_street_data }
    it "removes blanks" do
      expect(object.street).to eq nil
      expect(object.city).to eq nil
      expect(object.postal_code).to eq nil
    end
    describe "city name with region" do
      let!(:state) { FactoryBot.create(:state_new_york) }
      let(:object) { subject.class.new(country: Country.united_states, region_record: state, city: "New York, NY") }
      it "removes region" do
        expect(object.city).to eq "New York"
        expect(object.region_record_id).to eq state.id
      end
      context "region not set" do
        let(:object) { subject.class.new(country: Country.united_states, city: "New York,NY", region_record_id: nil) }
        it "sets region_record" do
          expect(object.city).to eq "New York"
          expect(object.region_record_id).to eq state.id
        end
      end
      context "larkspur" do
        let!(:state) { FactoryBot.create(:state, :find_or_create, name: "Colorado", abbreviation: "CO") }
        let(:object) { subject.class.new(country: Country.united_states, region_record: state, city: " larkspur . co\n") }
        it "removes co" do
          expect(object.city).to eq "larkspur"
          expect(object.region_record_id).to eq state.id
        end
      end
      context "Alberta" do
        let(:object) { subject.class.new(country: Country.canada, region_record: nil, city: " Edmonton, AB\n") }
        # Currently, not handling regions except US :(
        it "does not remove ab" do
          expect(object.city).to eq "Edmonton, AB"
          expect(object.region_record_id).to be_blank
        end
      end
    end
  end
end
