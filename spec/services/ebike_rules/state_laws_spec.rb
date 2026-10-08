# frozen_string_literal: true

require "rails_helper"

RSpec.describe EbikeRules::StateLaws do
  before { stub_bikebook_catalog }

  describe "find" do
    it "reads a state's e-bike law from the catalog" do
      expect(described_class.find("co")).to include(id: "evc/us/co/electric_bicycle", name: "Electrical Assisted Bicycle",
        classes: [1, 2, 3], watt_cap: 750, mph: 28, throttle: true)
      expect(described_class.find("CO")[:restrictions]).to include("Class 3 riders must be 16 or older; a younger passenger may ride on one designed to carry passengers")
      expect(described_class.find("CO")[:sources]).to include("https://leg.colorado.gov/bills/hb25-1197")
    end

    it "has no classes for a law that names none of the three" do
      expect(described_class.find("NY")).to include(classes: [], mph: 25)
    end

    it "is nil for a state without an e-bike law in the catalog, and no state" do
      expect(described_class.find("WY")).to be_nil
      expect(described_class.find(nil)).to be_nil
    end

    context "when the catalog is down" do
      before { WebMock.stub_request(:get, %r{bikebook-catalog\.bikeindex\.org}).to_return(status: 503) }

      it "is nil" do
        expect(described_class.find("CO")).to be_nil
        expect(described_class.laws).to be_nil
      end
    end
  end

  describe "classification_name" do
    let(:ids) { ["evc/us/ca/off_highway_electric_motorcycle"] }

    it "names the state's own classification, or the one sharing its group" do
      expect(described_class.classification_name("CA", ids)).to eq "Off-highway electric motorcycle"
      expect(described_class.classification_name("TX", ids)).to eq "Off-Highway Motorcycle"
      expect(described_class.classification_name("NY", ids)).to be_nil
      expect(described_class.classification_name("TX", [])).to be_nil
    end
  end
end
