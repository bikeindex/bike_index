require "rails_helper"

RSpec.describe SpamEstimator::Bike do
  describe "estimate" do
    context "frame_model" do
      let(:bike) { Bike.new(frame_model: str) }
      let(:str) { "Cutthroat" }
      it "is 0" do
        expect(SpamEstimator::Text.estimate(str)).to eq 0
        expect(described_class.estimate(bike)).to eq 0
      end
      context "FX 1 Disc" do
        let(:str) { "FX 1 Disc" }
        it "is 0" do
          expect(SpamEstimator::Text.estimate(str)).to be < 90
          expect(described_class.estimate(bike)).to be < 40
        end
      end
      context "garbage" do
        let(:str) { "efgBz9pNdd7efgBz9pNdd7" }
        it "estimate is percentage" do
          expect(SpamEstimator::Text.estimate(str)).to eq 100
          expect(described_class.estimate(bike)).to be_between(9, 20)
        end
      end
    end
    context "manufacturer_other" do
      let(:bike) { FactoryBot.build(:bike, manufacturer: Manufacturer.other, manufacturer_other: str) }
      context "garbage" do
        let(:str) { "VhriBJhD1nuwHoI9VhriBJhD1nuwHoI9" }
        it "estimate is percentage" do
          expect(SpamEstimator::Text.estimate(str)).to eq 100
          expect(described_class.estimate(bike)).to eq 40
        end
      end
      context "SON" do
        let(:str) { "SON Nabendynamo (Wilfried Schmidt Maschinenbau)" }
        it "returns" do
          expect(SpamEstimator::Text.estimate(str)).to be < 10
          expect(described_class.estimate(bike)).to be < 10
        end
      end
    end
    context "creation organization" do
      let(:bike) { Bike.new(creation_organization: organization) }
      let(:organization) { Organization.new }
      it "returns 0" do
        expect(described_class.estimate(bike)).to eq 0
      end
      context "spam_registrations" do
        let(:organization) { Organization.new(spam_registrations: true) }
        it "returns 40" do
          expect(described_class.estimate(bike)).to be_between(29, 41)
        end
      end
    end
    context "malicious cached_data" do
      let(:paint) { FactoryBot.create(:paint, name: "' UNION SELECT username, password FROM users--") }
      let(:bike) { FactoryBot.create(:bike, paint:) }
      it "returns 100" do
        expect(bike.cached_data).to include("union select")
        expect(described_class.estimate(bike)).to eq 100
      end
    end
    context "serial_number" do
      let(:bike) { Bike.new(serial_number: serial) }
      context "malicious" do
        let(:serial) { "x'; DROP TABLE bikes; --" }
        it "returns 100" do
          expect(bike.cached_data).to be_blank # the payload is in serial_number, not cached_data
          expect(described_class.estimate(bike)).to eq 100
        end
      end
      context "random-looking but not malicious" do
        let(:serial) { "VhriBJhD1nuwHoI9VhriBJhD1nuwHoI9" }
        it "is 0 (serial only scores via the injection check)" do
          expect(described_class.estimate(bike)).to eq 0
        end
      end
    end
    context "low-entropy fingerprint" do
      let(:bike) { Bike.new(serial_number: str, frame_model: str, manufacturer_other: str) }
      let(:str) { "xy" }
      it "adds a penalty" do
        expect(described_class.estimate(bike)).to eq 50
      end
      context "longer than 2 chars" do
        let(:str) { "xyz" }
        it "is not penalized" do
          expect(described_class.estimate(bike)).to eq 0
        end
      end
    end
    context "reserved owner_email domain" do
      before { stub_const("EmailDomain::VERIFICATION_ENABLED", true) }
      let(:bike) { Bike.new(owner_email: "testing@example.com") }
      it "returns 100" do
        expect(described_class.estimate(bike)).to eq 100
      end
    end
    context "stolen_record" do
      let(:bike) { Bike.new }
      let(:stolen_record) { StolenRecord.new(theft_description: str, street: street) }
      let(:str) { "It was stolen last night" }
      let(:street) { "5434 N Mains St" }
      it "is 0" do
        expect(described_class.estimate(bike, stolen_record)).to eq 0
      end
      context "garbage description" do
        let(:str) { "efgBz9pNdd7" }
        it "returns over 0" do
          expect(described_class.estimate(bike, stolen_record)).to be > 35
        end
      end
      context "garbage street" do
        let(:street) { "efgBz9pNdd7efgBz9pNdd7efgBz9pNdd7" }
        it "returns over 0" do
          expect(described_class.estimate(bike, stolen_record)).to eq 10
        end
        context "and garbage description" do
          let(:str) { "efgBz9pNdd7" }
          it "returns over 0" do
            expect(described_class.estimate(bike, stolen_record)).to be > 95
          end
        end
      end
    end
  end

  describe "low_entropy_fingerprint?" do
    def fingerprint?(bike)
      described_class.send(:low_entropy_fingerprint?, bike)
    end

    it "is true when serial/frame_model/manufacturer_other match and are 1-2 chars" do
      expect(fingerprint?(Bike.new(serial_number: "x", frame_model: "x", manufacturer_other: "x"))).to be_truthy
      expect(fingerprint?(Bike.new(serial_number: "AB", frame_model: " ab", manufacturer_other: "ab "))).to be_truthy
    end

    it "is false when a field is blank, fields differ, or longer than 2 chars" do
      expect(fingerprint?(Bike.new(serial_number: "x", frame_model: "x"))).to be_falsey
      expect(fingerprint?(Bike.new(serial_number: "x", frame_model: "y", manufacturer_other: "z"))).to be_falsey
      expect(fingerprint?(Bike.new(serial_number: "xyz", frame_model: "xyz", manufacturer_other: "xyz"))).to be_falsey
    end
  end

  describe "reserved_email_domain?" do
    it "is false for normal domains" do
      expect(described_class.send(:reserved_email_domain?, "rider@gmail.com")).to be_falsey
      expect(described_class.send(:reserved_email_domain?, "rider@myexample.com")).to be_falsey
      expect(described_class.send(:reserved_email_domain?, nil)).to be_falsey
    end

    it "is true for RFC 2606 reserved domains" do
      expect(described_class.send(:reserved_email_domain?, "testing@example.com")).to be_truthy
      expect(described_class.send(:reserved_email_domain?, "a@sub.example.org")).to be_truthy
      expect(described_class.send(:reserved_email_domain?, "a@thing.test")).to be_truthy
      expect(described_class.send(:reserved_email_domain?, "a@localhost")).to be_truthy
    end
  end
end
