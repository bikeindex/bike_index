require "rails_helper"

RSpec.describe SpamEstimator do
  describe "estimate_bike" do
    context "frame_model" do
      let(:bike) { Bike.new(frame_model: str) }
      let(:str) { "Cutthroat" }
      it "is 0" do
        expect(described_class.send(:string_spaminess, str)).to eq 0
        expect(described_class.estimate_bike(bike)).to eq 0
      end
      context "FX 1 Disc" do
        let(:str) { "FX 1 Disc" }
        it "is 0" do
          expect(described_class.send(:string_spaminess, str)).to be < 90
          expect(described_class.estimate_bike(bike)).to be < 40
        end
      end
      context "garbage" do
        let(:str) { "efgBz9pNdd7efgBz9pNdd7" }
        it "estimate is percentage" do
          expect(described_class.send(:string_spaminess, str)).to eq 100
          expect(described_class.estimate_bike(bike)).to eq 30
        end
      end
    end
    context "manufacturer_other" do
      let(:bike) { FactoryBot.build(:bike, manufacturer: Manufacturer.other, manufacturer_other: str) }
      context "garbage" do
        let(:str) { "VhriBJhD1nuwHoI9VhriBJhD1nuwHoI9" }
        it "estimate is percentage" do
          expect(described_class.send(:string_spaminess, str)).to eq 100
          expect(described_class.estimate_bike(bike)).to eq 40
        end
      end
      context "SON" do
        let(:str) { "SON Nabendynamo (Wilfried Schmidt Maschinenbau)" }
        it "returns" do
          expect(described_class.send(:string_spaminess, str)).to be < 10
          expect(described_class.estimate_bike(bike)).to be < 10
        end
      end
    end
    context "creation organization" do
      let(:bike) { Bike.new(creation_organization: organization) }
      let(:organization) { Organization.new }
      it "returns 0" do
        expect(described_class.estimate_bike(bike)).to eq 0
      end
      context "spam_registrations" do
        let(:organization) { Organization.new(spam_registrations: true) }
        it "returns 40" do
          expect(described_class.estimate_bike(bike)).to eq 40
        end
      end
    end
    context "stolen_record" do
      let(:bike) { Bike.new }
      let(:stolen_record) { StolenRecord.new(theft_description: str, street: street) }
      let(:str) { "It was stolen last night" }
      let(:street) { "1234 Main Street" }
      it "is 0" do
        expect(described_class.estimate_bike(bike, stolen_record)).to eq 0
      end
      context "garbage description" do
        let(:str) { "efgBz9pNdd7" }
        it "is 51" do
          expect(described_class.estimate_bike(bike, stolen_record)).to be > 80
        end
      end
      context "garbage street" do
        let(:street) { "efgBz9pNdd7" }
        it "is 51" do
          expect(described_class.estimate_bike(bike, stolen_record)).to be_between(50, 80)
        end
        context "and garbage description" do
          let(:str) { "efgBz9pNdd7" }
          it "is 51" do
            expect(described_class.estimate_bike(bike, stolen_record)).to eq 100
          end
        end
      end
    end
  end

  describe "string_spaminess" do
    context "garbage" do
      let(:str) { "VhriBJhD1nuwH" }
      it "returns for garbage" do
        expect(described_class.send(:vowel_frequency_suspiciousness, str)).to be_between(51, 80)
        expect(described_class.send(:capital_count_suspiciousness, str)).to be_between(0, 20)
        expect(described_class.send(:space_count_suspiciousness, str)).to be_between(5, 15)
        expect(described_class.send(:non_letter_count_suspiciousness, str)).to be_between(0, 20)
        expect(described_class.send(:string_spaminess, str)).to be_between(60, 81)
        # And double garbage
        expect(described_class.send(:vowel_frequency_suspiciousness, "#{str}#{str}")).to be_between(51, 80)
        expect(described_class.send(:capital_count_suspiciousness, "#{str}#{str}")).to be_between(10, 50)
        expect(described_class.send(:space_count_suspiciousness, "#{str}#{str}")).to be_between(51, 80)
        expect(described_class.send(:string_spaminess, "#{str}#{str}")).to eq 100
      end
    end
    context "frame_model names" do
      it "returns for proper frame_model names" do
        expect(described_class.send(:string_spaminess, "Cutthroat")).to eq 0
        expect(described_class.send(:string_spaminess, "Diverge 1.0")).to eq 0
        expect(described_class.send(:string_spaminess, "Skye S")).to eq 0
      end
    end
    context "Reward: 350" do
      let(:str) { "Reward: 350" }
      it "returns low" do
        expect(described_class.send(:vowel_ratio, str).round(2)).to eq 0.29
        expect(described_class.send(:vowel_frequency_suspiciousness, str)).to be < 10
        expect(described_class.send(:non_letter_count_suspiciousness, str)).to be < 15
        expect(described_class.send(:capital_count_suspiciousness, str)).to eq 0
        expect(described_class.send(:space_count_suspiciousness, str)).to eq 0
        expect(described_class.send(:string_spaminess, str)).to be < 30
      end
    end
    context "transliterate" do
      let(:str) { "Stålhästen" }
      it "returns true" do
        expect(described_class.send(:vowel_frequency_suspiciousness, str)).to be < 30
        expect(described_class.send(:non_letter_count_suspiciousness, str)).to eq 0
        expect(described_class.send(:capital_count_suspiciousness, str)).to eq 0
        expect(described_class.send(:space_count_suspiciousness, str)).to eq 0
        expect(described_class.send(:string_spaminess, str)).to be < 30
      end
    end
    context "some troublesome ones" do
      ["SON Nabendynamo (Wilfried Schmidt Maschinenbau)", "ENVE (ENVE Composites)",
        "Sturmey-Archer", "IRD (Interloc Racing Design)", "Louis Garneau", "DT Swiss",
        "Currie Technology (Currietech)", "VSF Fahrradmanufaktur", "PUBLIC bikes",
        "Mountainsmith"].each do |str|
        context "'#{str}'" do
          it "returns false" do
            # expect(described_class.send(:vowel_frequency_suspiciousness, str)).to be < 30
            # expect(described_class.send(:capital_count_suspiciousness, str)).to eq 0
            # expect(described_class.send(:space_count_suspiciousness, str)).to eq 0
            expect(described_class.send(:string_spaminess, str)).to be < 30
          end
        end
      end
    end
  end

  describe "vowel_frequency_suspiciousness" do
    context "very short" do
      it "scales based on how far out of frequency it is" do
        expect(described_class.send(:vowel_frequency_suspiciousness, "aei")).to eq 0
        expect(described_class.send(:vowel_frequency_suspiciousness, "xxx")).to eq 0

        expect(described_class.send(:vowel_frequency_suspiciousness, "aeiy")).to eq 40
        expect(described_class.send(:vowel_frequency_suspiciousness, "aeid")).to eq 0
        expect(described_class.send(:vowel_frequency_suspiciousness, "aedd")).to eq 0
        expect(described_class.send(:vowel_frequency_suspiciousness, "addd")).to be_between(0, 11)
        expect(described_class.send(:vowel_frequency_suspiciousness, "dddd")).to eq 40
      end
    end
    context "7 letters" do
      it "scales based on how far out of frequency it is" do
        expect(described_class.send(:vowel_frequency_suspiciousness, "aeiauyi")).to eq 100

        expect(described_class.send(:vowel_ratio, "aeiauyd").round(2)).to eq 0.86
        expect(described_class.send(:vowel_frequency_suspiciousness, "aeiauyd")).to be_between(85, 95)

        expect(described_class.send(:vowel_ratio, "aeiaudd").round(2)).to eq 0.71
        expect(described_class.send(:vowel_frequency_suspiciousness, "aeiaudd")).to be_between(60, 80)

        expect(described_class.send(:vowel_ratio, "aeiaddd").round(2)).to eq 0.57
        expect(described_class.send(:vowel_frequency_suspiciousness, "aeiaddd")).to be_between(15, 20)

        expect(described_class.send(:vowel_ratio, "aeidddd").round(2)).to eq 0.43
        expect(described_class.send(:vowel_frequency_suspiciousness, "aeidddd")).to be_between(0, 5)

        expect(described_class.send(:vowel_ratio, "aeddddd").round(2)).to eq 0.29
        expect(described_class.send(:vowel_frequency_suspiciousness, "aeddddd")).to eq 0

        expect(described_class.send(:vowel_ratio, "adddddd").round(2)).to eq 0.14
        expect(described_class.send(:vowel_frequency_suspiciousness, "DT Swiss")).to be_between(5, 30)

        expect(described_class.send(:vowel_ratio, "ddddddd")).to eq 0
        expect(described_class.send(:vowel_frequency_suspiciousness, "ddddddd")).to be_between(69, 100)
      end
    end
    context "15 letters" do
      it "scales based on how far out of frequency it is" do
        expect(described_class.send(:vowel_frequency_suspiciousness, "aeiauyaeiauyaei")).to eq 100

        expect(described_class.send(:vowel_ratio, "aeiauyaeiaudddd").round(2)).to eq 0.73
        expect(described_class.send(:vowel_frequency_suspiciousness, "aeiauyaeiaudddd")).to be_between(75, 100)

        expect(described_class.send(:vowel_ratio, "aaddddddddddddd").round(2)).to eq 0.13
        expect(described_class.send(:vowel_frequency_suspiciousness, "aaddddddddddddd")).to be_between(41, 95)
      end
    end
    context "> 30 letters" do
      it "scales based on how far out of frequency it is" do
        expect(described_class.send(:vowel_frequency_suspiciousness, "oaeiauyaeiauyaeiaeiauyaeiauyaei")).to eq 100

        expect(described_class.send(:vowel_ratio, "oaeiauyaeiauyaeiaeiauyaeiaudddd").round(2)).to eq 0.87
        expect(described_class.send(:vowel_frequency_suspiciousness, "oaeiauyaeiauyaeiaeiauyaeiaudddd").round).to eq 100

        expect(described_class.send(:vowel_ratio, "ddddddddddddddddddddddddddaaaaa").round(2)).to eq 0.16
        expect(described_class.send(:vowel_frequency_suspiciousness, "ddddddddddddddddddddddddddaaaaa").round).to be_between(73, 90)

        expect(described_class.send(:vowel_ratio, "ddddddddddddddddddddddddddddaaa").round(2)).to eq 0.1
        expect(described_class.send(:vowel_frequency_suspiciousness, "ddddddddddddddddddddddddddddaaa")).to eq 100

        expect(described_class.send(:vowel_frequency_suspiciousness, "dddddddddddddddddddddddddddddd")).to eq 100
      end
    end
  end

  describe "space_count_suspiciousness" do
    let(:str) { "1234567890" }
    it "returns 0" do
      expect(described_class.send(:space_count_suspiciousness, "#{str}1")).to eq 0
      expect(described_class.send(:space_count_suspiciousness, "123456 8901")).to eq 0
    end

    it "returns 10 at most for 12 characters" do
      expect(described_class.send(:space_count_suspiciousness, "#{str}12")).to eq 10
      expect(described_class.send(:space_count_suspiciousness, "#{str} 1")).to eq 0
    end

    it "returns percentage for 25 characters" do
      expect(described_class.send(:space_count_suspiciousness, "#{str}#{str}12345")).to eq 80
      expect(described_class.send(:space_count_suspiciousness, "#{str}#{str} 1234")).to eq 40
      expect(described_class.send(:space_count_suspiciousness, "#{str} #{str} 123")).to eq 0
    end

    context "35 characters" do
      it "returns percentage for 35 characters" do
        expect(described_class.send(:space_count_suspiciousness, "#{str}#{str}#{str}12345")).to eq 100
        expect(described_class.send(:space_count_suspiciousness, "#{str} #{str}#{str}1234")).to eq 60
        expect(described_class.send(:space_count_suspiciousness, "#{str} #{str} #{str}234")).to eq 0
      end
    end
  end

  describe "capital_count_suspiciousness" do
    let(:str) { "ABCABDEFGH" }
    it "returns 0" do
      expect(described_class.send(:capital_count_suspiciousness, "AAABBB")).to eq 0
      expect(described_class.send(:capital_count_suspiciousness, str.to_s)).to eq 50
      expect(described_class.send(:capital_count_suspiciousness, "#{str}f")).to be_between(25, 50)
    end

    it "returns 60 at most for 12 characters" do
      expect(described_class.send(:capital_count_suspiciousness, "#{str}AA")).to be_between(35, 60)
      expect(described_class.send(:capital_count_suspiciousness, "#{str}aa")).to be_between(30, 55)
      expect(described_class.send(:capital_count_suspiciousness, "AABBC DDeeaa")).to be_between(0, 10)
    end

    it "returns percentage for 25 characters" do
      expect(described_class.send(:capital_count_suspiciousness, "#{str}#{str}AABBC")).to eq 90
      expect(described_class.send(:capital_count_suspiciousness, "#{str}#{str}aabbc")).to eq 70
      expect(described_class.send(:capital_count_suspiciousness, "#{str}#{str} abbc")).to eq 70
      expect(described_class.send(:capital_count_suspiciousness, "#{str} #{str} bbc")).to eq 70
      expect(described_class.send(:capital_count_suspiciousness, "#{str}#{str.downcase}aabbc")).to eq 30
      expect(described_class.send(:capital_count_suspiciousness, "#{str.downcase}#{str.downcase}AABBC")).to be_between(0, 11)
    end
  end
end
