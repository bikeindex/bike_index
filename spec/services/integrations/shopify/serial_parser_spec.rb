require "rails_helper"

RSpec.describe Integrations::Shopify::SerialParser do
  describe "serials_in" do
    it "reads the labels shops actually write, and nothing that only looks like one" do
      expect(described_class.serials_in("Serial: WTU123K0912")).to eq(["WTU123K0912"])
      expect(described_class.serials_in("S/N: ABC123")).to eq(["ABC123"])
      expect(described_class.serials_in("SN: X1234")).to eq(["X1234"])
      expect(described_class.serials_in("S.N.: FR8842")).to eq(["FR8842"])
      expect(described_class.serials_in("Serial #WTU123")).to eq(["WTU123"])
      expect(described_class.serials_in("Serial No: ABC123")).to eq(["ABC123"])
      expect(described_class.serials_in("serial number: abc-123")).to eq(["abc-123"])
      expect(described_class.serials_in("Serial - WTU99")).to eq(["WTU99"])
      expect(described_class.serials_in(nil)).to eq([])
      expect(described_class.serials_in("Customer wants a tune-up")).to eq([])
    end

    it "finds every serial on a multi-bike sale, once each" do
      note = "Bike 1 Serial: AAA111\nBike 2 S/N: BBB222\nagain, serial: AAA111"
      expect(described_class.serials_in(note)).to eq(%w[AAA111 BBB222])
    end

    it "stops at the end of the serial rather than swallowing the rest of the note" do
      expect(described_class.serials_in("Bike serial: ABC123, helmet included")).to eq(["ABC123"])
    end

    # These are what the shop means by "there is no serial", not serials to register
    it "drops a label whose value says there isn't one" do
      expect(described_class.serials_in("Serial: none")).to eq([])
      expect(described_class.serials_in("Serial: N/A")).to eq([])
      expect(described_class.serials_in("Serial: unknown")).to eq([])
      expect(described_class.serials_in("Serial number not recorded")).to eq([])
    end

    context "no punctuation after the label" do
      it "takes a spelled-out label with a digit-bearing value" do
        expect(described_class.serials_in("S/N ABC123")).to eq(["ABC123"])
        expect(described_class.serials_in("Serial WTU123K0912")).to eq(["WTU123K0912"])
      end

      # Bare "sn" is only a label when punctuation ends it - otherwise it matches in "snowboard"
      it "does not read a bare sn, or a sentence, as a label" do
        expect(described_class.serials_in("I sold them a snowboard too")).to eq([])
        expect(described_class.serials_in("SN X1234")).to eq([])
        expect(described_class.serials_in("no serial on this one")).to eq([])
      end
    end
  end

  describe "serials_in_attributes" do
    it "reads the name as the label and the value as the serial" do
      attributes = [{"name" => "Serial", "value" => "WTU9981"},
        {"name" => "Gift wrap", "value" => "yes"}]
      expect(described_class.serials_in_attributes(attributes)).to eq(["WTU9981"])
    end

    it "is empty for anything that isn't a list of pairs" do
      expect(described_class.serials_in_attributes(nil)).to eq([])
      expect(described_class.serials_in_attributes([])).to eq([])
      expect(described_class.serials_in_attributes([{"name" => "Engraving", "value" => "Bee"}])).to eq([])
    end
  end
end
