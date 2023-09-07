require "rails_helper"

RSpec.describe SpamEstimator do
  describe "suspicious_string?" do
    context "vowels" do
      it "returns true" do
        expect(described_class.vowel_percentage("a")).to eq 1
        expect(described_class.suspicious_string?("a")).to be_truthy
        expect(described_class.vowel_percentage("aeiou")).to eq 1
        expect(described_class.suspicious_string?("aeiou")).to be_truthy
        expect(described_class.vowel_percentage("ay")).to eq 1
        expect(described_class.suspicious_string?("ay")).to be_falsey
      end
    end
    context "consonants" do
      it "returns true" do
        expect(described_class.vowel_percentage("z")).to eq 0
        expect(described_class.suspicious_string?("z")).to be_truthy
        expect(described_class.vowel_percentage("zf")).to eq 0
        expect(described_class.suspicious_string?("zf")).to be_falsey
      end
    end
    context "garbage" do
      let(:str) { "cRxFXMs3HC" }
      it "returns true" do
        expect(described_class.vowel_percentage(str)).to eq 0
        expect(described_class.suspicious_string?(str)).to be_truthy
      end
    end
    context "garbage" do
      let(:str) { "VhriBJhD1nuwHoI9" }
      it "returns true" do
        expect(described_class.vowel_percentage(str)).to eq 0.25
        expect(described_class.suspicious_space_count?(str)).to be_truthy
        expect(described_class.suspicious_string?(str)).to be_truthy
      end
    end
    context "Kinn" do
      let(:str) { "Kinn" }
      it "returns false" do
        expect(described_class.vowel_percentage(str)).to eq 0.25
        expect(described_class.suspicious_string?(str)).to be_falsey
      end
    end
    context "some troublesome ones" do
      ["SON Nabendynamo (Wilfried Schmidt Maschinenbau)", "ENVE (ENVE Composites)",
       "Sturmey-Archer", "IRD (Interloc Racing Design)", "Louis Garneau",
       "Currie Technology (Currietech)", "VSF Fahrradmanufaktur"].each do |str|
        context "'#{str}'" do
          it "returns false" do
            # pp described_class.vowel_percentage(str)
            expect(described_class.suspicious_vowel_frequency?(str)).to be_falsey
            expect(described_class.suspicious_space_count?(str)).to be_falsey
            expect(described_class.suspicious_capital_count?(str)).to be_falsey
            expect(described_class.suspicious_string?(str)).to be_falsey
          end
        end
      end
    end
    context "transliterate" do
      let(:str) { "Stålhästen" }
      it "returns true" do
        expect(described_class.vowel_percentage(str).round(2)).to eq 0.3
        expect(described_class.suspicious_vowel_frequency?(str)).to be_falsey
        expect(described_class.suspicious_space_count?(str)).to be_falsey
        expect(described_class.suspicious_string?(str)).to be_falsey
      end
    end
  end

  # describe "manufacturer_other" do
  #   let(:bike) { FactoryBot.build(:bike, manufacturer: Manufacturer.other, manufacturer_other: str) }
  #   context "garbage" do
  #     let(:str) { "VhriBJhD1nuwHoI9" }
  #     it "returns 100" do
  #       expect(described_class.estimate_bike(bike)).to eq 100
  #     end
  #   end
  #   context "SON" do
  #     let(:str) { "SON Nabendynamo (Wilfried Schmidt Maschinenbau)" }
  #     it "returns 0" do
  #       expect(described_class.estimate_bike(bike)).to eq 0
  #     end
  #   end
  # end
end


