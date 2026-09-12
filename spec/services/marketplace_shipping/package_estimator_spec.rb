require "rails_helper"

RSpec.describe MarketplaceShipping::PackageEstimator do
  describe "estimate_for" do
    # validate to run the frame_size normalization that splits it into number and unit
    let(:bike) { Bike.new(frame_size:).tap(&:validate) }
    let(:frame_size) { nil }
    let(:medium) { {length: 45, width: 12, height: 30, weight_pounds: 45} }
    let(:extra_large) { {length: 56, width: 21, height: 32, weight_pounds: 55} }

    it "is the medium box" do
      expect(described_class.estimate_for(bike)).to eq medium
    end

    context "small centimeter frame" do
      let(:frame_size) { "54cm" }

      it "is the medium box" do
        expect(bike.frame_size_unit).to eq "cm"
        expect(described_class.estimate_for(bike)).to eq medium
      end
    end

    context "large centimeter frame" do
      let(:frame_size) { "58cm" }

      it "is the extra large box" do
        expect(described_class.estimate_for(bike)).to eq extra_large
      end
    end

    context "large inch frame" do
      let(:frame_size) { "23in" }

      it "is the extra large box" do
        expect(bike.frame_size_unit).to eq "in"
        expect(described_class.estimate_for(bike)).to eq extra_large
      end
    end

    context "ordinal frame" do
      let(:frame_size) { "large" }

      it "is the extra large box" do
        expect(bike.frame_size_unit).to eq "ordinal"
        expect(bike.frame_size).to eq "l"
        expect(described_class.estimate_for(bike)).to eq extra_large
      end
    end

    context "small ordinal frame" do
      let(:frame_size) { "small" }

      it "is the medium box" do
        expect(described_class.estimate_for(bike)).to eq medium
      end
    end

    context "no bike" do
      it "is the medium box" do
        expect(described_class.estimate_for(nil)).to eq medium
      end
    end
  end
end
