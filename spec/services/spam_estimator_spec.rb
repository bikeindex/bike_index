require "rails_helper"

RSpec.describe SpamEstimator do
  describe "vowel_frequency_suspiciousness" do
    context "very short" do
      it "scales based on how far out of frequency it is" do
        expect(described_class.vowel_frequency_suspiciousness("aei")).to eq 0
        expect(described_class.vowel_frequency_suspiciousness("xxx")).to eq 0

        expect(described_class.vowel_frequency_suspiciousness("aeiy")).to eq 40
        expect(described_class.vowel_frequency_suspiciousness("aeid")).to eq 0
        expect(described_class.vowel_frequency_suspiciousness("aedd")).to eq 0
        expect(described_class.vowel_frequency_suspiciousness("addd")).to be_between(0, 11)
        expect(described_class.vowel_frequency_suspiciousness("dddd")).to eq 40
      end
    end
    context "7 letters" do
      it "scales based on how far out of frequency it is" do
        expect(described_class.vowel_frequency_suspiciousness("aeiauyi")).to eq 100

        expect(described_class.vowel_ratio("aeiauyd").round(2)).to eq 0.86
        expect(described_class.vowel_frequency_suspiciousness("aeiauyd")).to be_between(85, 95)

        expect(described_class.vowel_ratio("aeiaudd").round(2)).to eq 0.71
        expect(described_class.vowel_frequency_suspiciousness("aeiaudd")).to be_between(60, 80)

        expect(described_class.vowel_ratio("aeiaddd").round(2)).to eq 0.57
        expect(described_class.vowel_frequency_suspiciousness("aeiaddd")).to be_between(15, 20)

        expect(described_class.vowel_ratio("aeidddd").round(2)).to eq 0.43
        expect(described_class.vowel_frequency_suspiciousness("aeidddd")).to be_between(0, 5)

        expect(described_class.vowel_ratio("aeddddd").round(2)).to eq 0.29
        expect(described_class.vowel_frequency_suspiciousness("aeddddd")).to eq 0

        expect(described_class.vowel_ratio("adddddd").round(2)).to eq 0.14
        expect(described_class.vowel_frequency_suspiciousness("DT Swiss")).to be_between(5, 30)

        expect(described_class.vowel_ratio("ddddddd")).to eq 0
        expect(described_class.vowel_frequency_suspiciousness("ddddddd")).to be_between(69, 100)
      end
    end
    context "15 letters" do
      it "scales based on how far out of frequency it is" do
        expect(described_class.vowel_frequency_suspiciousness("aeiauyaeiauyaei")).to eq 100

        expect(described_class.vowel_ratio("aeiauyaeiaudddd").round(2)).to eq 0.73
        expect(described_class.vowel_frequency_suspiciousness("aeiauyaeiaudddd")).to be_between(75, 100)

        expect(described_class.vowel_ratio("aaddddddddddddd").round(2)).to eq 0.13
        expect(described_class.vowel_frequency_suspiciousness("aaddddddddddddd")).to be_between(41, 95)
      end
    end
    context "> 30 letters" do
      it "scales based on how far out of frequency it is" do
        expect(described_class.vowel_frequency_suspiciousness("oaeiauyaeiauyaeiaeiauyaeiauyaei")).to eq 100

        expect(described_class.vowel_ratio("oaeiauyaeiauyaeiaeiauyaeiaudddd").round(2)).to eq 0.87
        expect(described_class.vowel_frequency_suspiciousness("oaeiauyaeiauyaeiaeiauyaeiaudddd").round).to eq 100

        expect(described_class.vowel_ratio("ddddddddddddddddddddddddddaaaaa").round(2)).to eq 0.16
        expect(described_class.vowel_frequency_suspiciousness("ddddddddddddddddddddddddddaaaaa").round).to be_between(73, 90)

        expect(described_class.vowel_ratio("ddddddddddddddddddddddddddddaaa").round(2)).to eq 0.1
        expect(described_class.vowel_frequency_suspiciousness("ddddddddddddddddddddddddddddaaa")).to eq 100

        expect(described_class.vowel_frequency_suspiciousness("dddddddddddddddddddddddddddddd")).to eq 100
      end
    end
    context "some troublesome ones" do
      ["SON Nabendynamo (Wilfried Schmidt Maschinenbau)", "ENVE (ENVE Composites)",
      "Sturmey-Archer", "IRD (Interloc Racing Design)", "Louis Garneau", "DT Swiss",
      "Currie Technology (Currietech)", "VSF Fahrradmanufaktur", "PUBLIC bikes"].each do |str|
        context "'#{str}'" do
          it "returns false" do
            # pp described_class.vowel_ratio(str)
            expect(described_class.vowel_frequency_suspiciousness(str)).to be < 30
            # expect(described_class.suspicious_space_count?(str)).to be_falsey
            # expect(described_class.suspicious_capital_count?(str)).to be_falsey
            # expect(described_class.suspicious_string?(str)).to be_falsey
          end
        end
      end
    end
  end

  # describe "string_spaminess" do
  #   context "vowels" do
  #     it "returns low" do
  #       expect(described_class.string_spaminess(" ")).to eq 0
  #       expect(described_class.vowel_ratio("a")).to eq 1
  #       expect(described_class.string_spaminess("a")).to eq 10
  #     end
  #     it "returns for aeiou" do
  #       expect(described_class.vowel_ratio("aeiou")).to eq 1
  #       expect(described_class.vowel_frequency_suspiciousness("aeiou")).to eq 80
  #       expect(described_class.string_spaminess("aeiou")).to eq 60
  #     end
  #     it "returns for ay" do
  #       expect(described_class.vowel_ratio("ay")).to eq 1
  #       expect(described_class.vowel_frequency_suspiciousness("ay")).to eq 10
  #       expect(described_class.string_spaminess("ay")).to eq 10
  #     end
  #   end
  #   # context "consonants" do
  #   #   it "returns true" do
  #   #     expect(described_class.vowel_ratio("z")).to eq 0
  #   #     expect(described_class.string_spaminess("z")).to eq 10
  #   #     expect(described_class.vowel_ratio("zf")).to eq 0
  #   #     expect(described_class.string_spaminess("zf")).to eq 0
  #   #   end
  #   # end
  #   context "garbage" do
  #     let(:str) { "VhriBJhD1nuwH" }
  #     it "returns for garbage" do
  #       expect(described_class.vowel_frequency_suspiciousness(str)).to eq 80
  #       expect(described_class.string_spaminess(str)).to eq 80
  #       # And double garbage
  #       expect(described_class.vowel_frequency_suspiciousness(str + str)).to eq 80
  #       expect(described_class.string_spaminess(str + str)).to eq 100
  #     end
  #   end
  #   context "frame_model names" do
  #     it "returns for proper frame_model names" do
  #       expect(described_class.string_spaminess("Cutthroat")).to eq 0
  #       expect(described_class.string_spaminess("Diverge 1.0")).to eq 0
  #       expect(described_class.string_spaminess("Skye S")).to eq 0
  #       expect(described_class.string_spaminess("FX 1 Disc")).to eq 0
  #     end
  #   end
  #   # context "garbage" do
  #   #   let(:str) { "VhriBJhD1nuwHoI9" }
  #   #   it "returns true" do
  #   #     expect(described_class.vowel_ratio(str)).to eq 0.25
  #   #     expect(described_class.suspicious_space_count?(str)).to be_truthy
  #   #     expect(described_class.suspicious_string?(str)).to be_truthy
  #   #   end
  #   # end
  #   # context "transliterate" do
  #   #   let(:str) { "Stålhästen" }
  #   #   it "returns true" do
  #   #     expect(described_class.vowel_ratio(str).round(2)).to eq 0.3
  #   #     expect(described_class.suspicious_vowel_frequency?(str)).to be_falsey
  #   #     expect(described_class.suspicious_space_count?(str)).to be_falsey
  #   #     expect(described_class.suspicious_string?(str)).to be_falsey
  #   #   end
  #   # end
  #   # context "testing" do
  #   #   let(:str) { "Mountainsmith" }
  #   #   it "returns false" do
  #   #     expect(described_class.suspicious_vowel_frequency?(str)).to be_falsey
  #   #     expect(described_class.suspicious_space_count?(str)).to be_falsey
  #   #     expect(described_class.suspicious_capital_count?(str)).to be_falsey
  #   #     expect(described_class.suspicious_string?(str)).to be_falsey
  #   #   end
  #   # end
  #   # context "some troublesome ones" do
  #   #   ["SON Nabendynamo (Wilfried Schmidt Maschinenbau)", "ENVE (ENVE Composites)",
  #   #     "Sturmey-Archer", "IRD (Interloc Racing Design)", "Louis Garneau", "DT Swiss",
  #   #     "Currie Technology (Currietech)", "VSF Fahrradmanufaktur", "PUBLIC bikes"].each do |str|
  #   #     context "'#{str}'" do
  #   #       it "returns false" do
  #   #         # pp described_class.vowel_ratio(str)
  #   #         expect(described_class.suspicious_vowel_frequency?(str)).to be_falsey
  #   #         expect(described_class.suspicious_space_count?(str)).to be_falsey
  #   #         expect(described_class.suspicious_capital_count?(str)).to be_falsey
  #   #         expect(described_class.suspicious_string?(str)).to be_falsey
  #   #       end
  #   #     end
  #   #   end
  #   # end
  # end

  # # describe "estimate_bike" do
  # #   context "frame_model" do
  # #     let(:bike) { Bike.new(frame_model: str) }
  # #     let(:str) { "Cutthroat" }
  # #     it "is 0" do
  # #       expect(described_class.string_spaminess(str)).to eq 0
  # #       expect(described_class.estimate_bike(bike)).to eq 0
  # #     end
        # "CAAD 8"
  # #     context "garbage" do
  # #       let(:str) { "efgBz9pNdd7efgBz9pNdd7" }
  # #       it "estimate is percentage" do
  # #         expect(described_class.string_spaminess(str)).to eq 100
  # #         expect(described_class.estimate_bike(bike)).to eq 50
  # #       end
  # #     end
  # #   end
  # #   context "manufacturer_other" do
  # #     let(:bike) { FactoryBot.build(:bike, manufacturer: Manufacturer.other, manufacturer_other: str) }
  # #     context "garbage" do
  # #       let(:str) { "VhriBJhD1nuwHoI9VhriBJhD1nuwHoI9" }
  # #       it "estimate is percentage" do
  # #         expect(described_class.string_spaminess(str)).to eq 100
  # #         expect(described_class.estimate_bike(bike)).to eq 30
  # #       end
  # #     end
  # #     context "SON" do
  # #       let(:str) { "SON Nabendynamo (Wilfried Schmidt Maschinenbau)" }
  # #       it "returns" do
  # #         expect(described_class.string_spaminess(str)).to eq 30
  # #         expect(described_class.estimate_bike(bike)).to eq 15
  # #       end
  # #     end
  # #   end
  # #   context "creation organization" do
  # #     let(:bike) { Bike.new(creation_organization: organization) }
  # #     let(:organization) { Organization.new }
  # #     it "returns 0" do
  # #       expect(described_class.estimate_bike(bike)).to eq 0
  # #     end
  # #     context "spam_registrations" do
  # #       let(:organization) { Organization.new(spam_registrations: true) }
  # #       it "returns 40" do
  # #         expect(described_class.estimate_bike(bike)).to eq 40
  # #       end
  # #     end
  # #   end
  # #   # context "stolen_record" do
  # #   #   let(:bike) { Bike.new }
  # #   #   let(:stolen_record) { StolenRecord.new(theft_description: str, street: street) }
  # #   #   let(:str) { "It was stolen last night" }
  # #   #   let(:street) { "1234 Main Street" }
  # #   #   it "is 0" do
  # #   #     expect(described_class.estimate_bike(bike, stolen_record)).to eq 0
  # #   #   end
  # #   #   context "garbage" do
  # #   #     let(:str) { "efgBz9pNdd7" }
  # #   #     it "is 51" do
  # #   #       expect(described_class.estimate_bike(bike, stolen_record)).to eq 51
  # #   #     end
  # #   #   end
  # #   #   context "garbage" do
  # #   #     let(:street) { "efgBz9pNdd7" }
  # #   #     it "is 51" do
  # #   #       expect(described_class.estimate_bike(bike, stolen_record)).to eq 21
  # #   #     end
  # #   #   end
  # #   # end
  # # end
end
