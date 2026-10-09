# frozen_string_literal: true

require "rails_helper"

RSpec.describe EbikeRuleServices::StateLaws do
  before { stub_bikebook_catalog }

  describe "find" do
    it "reads a state's e-bike law from the catalog" do
      expect(described_class.find("CO")).to include(id: "evc/us/co/electric_bicycle", name: "Electrical Assisted Bicycle",
        classes: [1, 2, 3], watt_cap: 750, mph: 28, throttle: true)
      expect(described_class.find("CO")[:restrictions])
        .to include({rule: "Class 3 riders must be 16 or older; a younger passenger may ride on one designed to carry passengers", starts_on: nil, ends_on: nil})
      expect(described_class.find("CO")[:sources]).to include("https://leg.colorado.gov/bills/hb25-1197")
    end

    it "has no classes for a law that names none of the three" do
      expect(described_class.find("NY")).to include(classes: [], mph: 25)
    end

    it "is nil for a state without an e-bike law in the catalog" do
      expect(described_class.find("WY")).to be_nil
    end

    it "takes Alaska's e-bike law, though it's for state parks rather than roads" do
      expect(described_class.find("AK")).to include(classes: [], watt_cap: 750, throttle: true)
    end

    it "drops a rule once it ends, and keeps a rule's start date until it starts" do
      san_mateo = "Cities in San Mateo County may bar riders under 12 from Class 1 and Class 2 electric bicycles"
      sidewalks = /\AA 10 mph prima facie speed limit on sidewalks/

      expect(described_class.find("CA", today: Date.new(2026, 10, 8))[:restrictions])
        .to include({rule: san_mateo, starts_on: Date.new(2027, 1, 1), ends_on: Date.new(2031, 1, 1)},
          {rule: sidewalks, starts_on: Date.new(2027, 1, 1), ends_on: nil})
      expect(described_class.find("CA", today: Date.new(2027, 1, 1))[:restrictions])
        .to include({rule: san_mateo, starts_on: nil, ends_on: Date.new(2031, 1, 1)}, {rule: sidewalks, starts_on: nil, ends_on: nil})
      after_san_mateo = described_class.find("CA", today: Date.new(2031, 1, 1))[:restrictions].pluck(:rule)
      expect(after_san_mateo).to include(sidewalks)
      expect(after_san_mateo).not_to include(san_mateo)
    end

    it "keeps a law's limits_start_on only until its limits are in force" do
      motor_alone = "Its top speed on motor power alone on level ground is 20 mph"

      before_the_law = described_class.find("NC", today: Date.new(2026, 11, 30))
      expect(before_the_law).to include(limits_start_on: Date.new(2026, 12, 1), classes: [1, 2, 3])
      expect(before_the_law[:restrictions]).to include({rule: motor_alone, starts_on: nil, ends_on: Date.new(2026, 12, 1)})

      in_force = described_class.find("NC", today: Date.new(2026, 12, 1))
      expect(in_force).to include(limits_start_on: nil)
      expect(in_force[:restrictions].pluck(:rule)).not_to include(motor_alone)
    end

    it "goes by a state's electric_bicycle law when it has another, whichever comes first" do
      vocabulary = JSON.parse(BikebookCatalogHelpers::FIXTURES.join("vocabulary.json").read)
      classifications = vocabulary["e_vehicle_classifications"]
      vocabulary["e_vehicle_classifications"] = {"evc/us/co/bicycle" => {"name" => "Bicycle"}, **classifications,
                                                 "evc/us/co/low_speed_electric_bicycle" => {"name" => "Low-Speed Electric Bicycle"}}
      WebMock.stub_request(:get, "#{Integrations::Bikebook::Catalog::URL}vocabulary.json").to_return(body: vocabulary.to_json)

      expect(described_class.find("CO")).to include(id: "evc/us/co/electric_bicycle")
    end

    context "when the catalog is down" do
      before { WebMock.stub_request(:get, %r{bikebook-catalog\.bikeindex\.org}).to_return(status: 503) }

      it "is empty" do
        expect(described_class.laws).to eq({})
      end
    end
  end

  describe "state" do
    it "finds a state by its abbreviation in either case, and nothing else" do
      expect(described_class.state("co")).to include(name: "Colorado")
      expect(described_class.state("PR")).to be_nil
      expect(described_class.state(["co"])).to be_nil
      expect(described_class.state(nil)).to be_nil
    end
  end

  describe "classification_name" do
    let(:ids) { ["evc/us/ca/off_highway_electric_motorcycle"] }

    it "names the state's own classification, or the one sharing its group" do
      expect(described_class.classification_name("CA", ids)).to eq "Off-highway electric motorcycle"
      expect(described_class.classification_name("TX", ids)).to eq "Off-Highway Motorcycle"
      expect(described_class.classification_name("NY", ids)).to be_nil
      expect(described_class.classification_name("TX", [])).to be_nil
      # not the state's e-bike law, which a Class 3 shares a group with
      expect(described_class.classification_name("TX", ["evc/us/class_3"])).to be_nil
    end
  end
end
