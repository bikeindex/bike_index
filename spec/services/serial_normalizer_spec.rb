require "rails_helper"

RSpec.describe SerialNormalizer do
  describe "unknown_and_absent_corrected" do
    it "returns serials that are passed to it" do
      expect(SerialNormalizer.unknown_and_absent_corrected("   787CCdddWTu ")).to eq "787CCdddWTu"
      # It also returns correctly if there are some ?s in the string
      expect(SerialNormalizer.unknown_and_absent_corrected("   787CC???WTu ")).to eq "787CC???WTu"
      # Also, check that we don't mark things unknown that look sort of like unknown but aren't
      expect(SerialNormalizer.unknown_and_absent_corrected("Kno1111")).to eq "Kno1111"
    end

    it "normalizes blank and strips" do
      expect(SerialNormalizer.unknown_and_absent_corrected("   \n")).to eq "unknown"
      expect(SerialNormalizer.unknown_and_absent_corrected(" absenT   \n")).to eq "unknown"
      expect(SerialNormalizer.unknown_and_absent_corrected("   UNKNOWN \n")).to eq "unknown"
      expect(SerialNormalizer.unknown_and_absent_corrected("   missing \n")).to eq "unknown"
    end

    context "misentries" do
      let(:sample_misentries) do
        [
          "dont know ", "I don't know it", "i dont fucking know", "sadly I don't know... ", "I do not remember",
          "???? ??", "Unknown Serial", "IDONTKNOWTHESERIALNUMBER", "I dont remember", "Not known", "dont no", "missing",
          "n/a", "do not have", "idk", "unkown", "none", "no serial",
        ]
      end
      it "normalizes a bunch of misentries" do
        sample_misentries.each do |serial|
          expect(SerialNormalizer.unknown_and_absent_corrected(serial)).to eq("unknown"), "Failure: '#{serial}'"
        end
      end
    end
  end

  describe "made_without_serial" do
    it "returns made_without_serial and normalizes to nil" do
      expect(SerialNormalizer.unknown_and_absent_corrected("made_without_serial")).to eq "made_without_serial"
      serial_normalizer = SerialNormalizer.new(serial: "made_without_serial")
      expect(serial_normalizer.normalized).to be_nil
      expect(serial_normalizer.normalized_segments).to eq([])
    end

    context "verbose entries" do
      entries = [
        "custom bike no serial has a unique frame design",
        "custom built ",
        " custom ",
      ]
      entries.each do |entry|
        it "normalizes '#{entry}' to 'made_without_serial'" do
          corrected_serial = SerialNormalizer.unknown_and_absent_corrected(entry)
          expect(corrected_serial).to eq("made_without_serial")
        end
      end
    end
  end

  describe "normalize" do
    it "normalizes i o 5 2 z and b" do
      serial = "bobs-catzio"
      result = SerialNormalizer.new(serial: serial).normalized
      expect(result).to eq("8085 CAT210")
    end
    it "normalizes -_+= and multiple spaces" do
      serial = "s>e-r--i+a_l"
      result = SerialNormalizer.new(serial: serial).normalized
      expect(result).to eq("5 E R 1 A 1")
    end
    it "remove leading zeros and ohs" do
      serial = "00O38675971596"
      result = SerialNormalizer.new(serial: serial).normalized
      expect(result).to eq("38675971596")
    end
    it "returns absent unless present" do
      expect(SerialNormalizer.new(serial: " ").normalized).to be_nil
    end
  end

  describe "normalized_segments" do
    it "makes normalized segments" do
      segments = SerialNormalizer.new(serial: "some + : serial").normalized_segments
      expect(segments.count).to eq(2)
      expect(segments[0]).to eq("50ME")
    end
    it "returns nil if serial is absent" do
      segments = SerialNormalizer.new(serial: "unknown").normalized_segments
      expect(segments).to eq([])
    end
  end

  describe "save_segments" do
    it "saves normalized segments with the bike_id and not break if we resave" do
      bike = FactoryBot.create(:bike)
      SerialNormalizer.new(serial: "some + : serial").save_segments(bike.id)
      expect(NormalizedSerialSegment.where(bike_id: bike.id).count).to eq(2)
    end

    it "does not save made_without_serial segments" do
      bike = FactoryBot.create(:bike)
      SerialNormalizer.new(serial: "made_without_serial").save_segments(bike.id)
      expect(NormalizedSerialSegment.where(bike_id: bike.id).count).to eq(0)
    end

    it "does not save unknown segments" do
      bike = FactoryBot.create(:bike)
      SerialNormalizer.new(serial: "unknown").save_segments(bike.id)
      expect(NormalizedSerialSegment.where(bike_id: bike.id).count).to eq(0)
    end

    it "rewrites the segments if we save them a second time" do
      bike = FactoryBot.create(:bike)
      SerialNormalizer.new(serial: "some + : serial").save_segments(bike.id)
      expect(NormalizedSerialSegment.where(bike_id: bike.id).count).to eq(2)
      SerialNormalizer.new(serial: "another + : THING").save_segments(bike.id)
      segments = NormalizedSerialSegment.where(bike_id: bike.id)
      expect(segments.count).to eq(2)
      seg_strings = segments.map(&:segment)
      expect(seg_strings.include?("AN0THER")).to be_truthy
      expect(seg_strings.include?("TH1NG")).to be_truthy
    end

    it "does not make any if the bike is an example bike" do
      bike = FactoryBot.create(:bike)
      bike.update_attributes(example: true)
      SerialNormalizer.new(serial: "some + : serial").save_segments(bike.id)
      expect(NormalizedSerialSegment.where(bike_id: bike.id).count).to eq(0)
    end
  end
end
