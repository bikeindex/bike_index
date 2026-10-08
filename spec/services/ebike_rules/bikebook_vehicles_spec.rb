# frozen_string_literal: true

require "rails_helper"

RSpec.describe EbikeRules::BikebookVehicles do
  before { stub_bikebook_catalog }

  describe "find" do
    it "reads a model's class, motor, speeds and certifications" do
      bike = described_class.find("m/specialized/2025/haul_st")

      expect(bike).to have_attributes(bikebook_id: "m/specialized/2025/haul_st", manufacturer_name: "Specialized",
        model: "Haul ST", first_year: 2025, e_bike_class: 3, e_vehicle_classifications: %w[evc/us/class_3 evc/us/class_2], watts: 700, top_assist_mph: 28, throttle: true,
        throttle_mph: 20, ul2849: :certified, ul2271: :certified, manual?: false)
    end

    it "classes an unclassified model by its speeds" do
      expect(described_class.find("m/aventon/2022/level_2"))
        .to have_attributes(e_bike_class: 1, watts: 500, top_assist_mph: 20, throttle: false)
    end

    it "gives no class to a model too fast for one" do
      expect(described_class.find("m/segway/2025/gt3_pro")).to have_attributes(e_bike_class: nil, watts: 1700, throttle: true)
    end

    it "gives no class to a model classified as something else" do
      expect(described_class.find("m/sur_ron/2026/ultra_bee_hp_x_us"))
        .to have_attributes(e_bike_class: nil, e_vehicle_classifications: %w[evc/us/ca/off_highway_electric_motorcycle evc/off_highway_motorcycle])
    end

    it "is nil for a model the catalog lacks, a model without a motor, and no id" do
      expect(described_class.find("m/specialized/2025/nothing")).to be_nil
      expect(described_class.find("m/kris_holm/2023/kh20")).to be_nil
      expect(described_class.find(nil)).to be_nil
    end

    context "when the catalog is down" do
      before { WebMock.stub_request(:get, %r{bikebook-catalog\.bikeindex\.org}).to_return(status: 503) }

      it "is nil" do
        expect(described_class.find("m/specialized/2025/haul_st")).to be_nil
      end
    end
  end
end
