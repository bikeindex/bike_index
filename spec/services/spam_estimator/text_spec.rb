require "rails_helper"

RSpec.describe SpamEstimator::Text do
  describe "estimate" do
    context "garbage" do
      let(:str) { "VhriBJhD1nuwH" }
      it "returns for garbage" do
        expect(described_class.send(:vowel_frequency_suspiciousness, str)).to be_between(51, 80)
        expect(described_class.send(:capital_count_suspiciousness, str)).to be_between(0, 20)
        expect(described_class.send(:space_count_suspiciousness, str)).to be_between(5, 15)
        expect(described_class.send(:non_letter_count_suspiciousness, str)).to be_between(0, 20)
        expect(described_class.estimate(str)).to be_between(60, 81)
        # And double garbage
        expect(described_class.send(:vowel_frequency_suspiciousness, "#{str}#{str}")).to be_between(51, 80)
        expect(described_class.send(:capital_count_suspiciousness, "#{str}#{str}")).to be_between(5, 30)
        expect(described_class.send(:space_count_suspiciousness, "#{str}#{str}")).to be_between(51, 80)
        expect(described_class.estimate("#{str}#{str}")).to eq 100
      end
    end
    context "frame_model names" do
      it "returns for proper frame_model names" do
        expect(described_class.estimate("Cutthroat")).to eq 0
        expect(described_class.estimate("Diverge 1.0")).to eq 0
        expect(described_class.estimate("Skye S")).to eq 0
      end
    end
    context "5434 N Mains St" do
      let(:str) { "5434 N Mains St" }
      it "returns low" do
        # expect(described_class.send(:vowel_ratio, str).round(2)).to eq 0.18
        expect(described_class.send(:vowel_frequency_suspiciousness, str)).to be < 80
        expect(described_class.send(:non_letter_count_suspiciousness, str)).to be < 15
        expect(described_class.send(:capital_count_suspiciousness, str)).to eq 0
        expect(described_class.send(:space_count_suspiciousness, str)).to eq 0
        expect(described_class.estimate(str)).to be < 65
      end
    end
    context "transliterate" do
      let(:str) { "Stålhästen" }
      it "returns true" do
        expect(described_class.send(:vowel_frequency_suspiciousness, str)).to be < 30
        expect(described_class.send(:non_letter_count_suspiciousness, str)).to eq 0
        expect(described_class.send(:capital_count_suspiciousness, str)).to eq 0
        expect(described_class.send(:space_count_suspiciousness, str)).to eq 0
        expect(described_class.estimate(str)).to be < 30
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
            expect(described_class.estimate(str)).to be < 30
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

  describe "looks_malicious?" do
    it "is false for blank strings" do
      expect(described_class.send(:looks_malicious?, nil)).to be_falsey
      expect(described_class.send(:looks_malicious?, "")).to be_falsey
    end

    it "is false for benign strings" do
      expect(described_class.send(:looks_malicious?, "Surly Cross-Check")).to be_falsey
      expect(described_class.send(:looks_malicious?, "5434 N Mains St")).to be_falsey
      expect(described_class.send(:looks_malicious?, "It was stolen last night")).to be_falsey
      expect(described_class.send(:looks_malicious?, "Diverge 1.0")).to be_falsey
      expect(described_class.send(:looks_malicious?, "SON Nabendynamo (Wilfried Schmidt Maschinenbau)")).to be_falsey
    end

    it "is false for markdown/html strings" do
      str = "so long as you don't spend too much time thinking about torture, the lack of sanitation, or [Theon Greyjoy](http://en.wikipedia.org/wiki/Theon_Greyjoy#Theon_Greyjoy).\r\n\r\n<img class=\"post-image\" src=\"https://files.bikeindex.org/uploads/Pu/1136/large_sketch.jpg\" alt=\"Sketch of some medieval things. Inspiration for Bike Index illustrations"
      expect(described_class.send(:looks_malicious?, str)).to be_falsey
    end

    it "detects XSS attempts" do
      expect(described_class.send(:looks_malicious?, "<script>alert('xss')</script>")).to be_truthy
      expect(described_class.send(:looks_malicious?, "< SCRIPT >alert(1)</script>")).to be_truthy
      expect(described_class.send(:looks_malicious?, "<iframe src='evil.com'></iframe>")).to be_truthy
      expect(described_class.send(:looks_malicious?, "<IMG SRC=javascript:alert('XSS')>")).to be_truthy
      expect(described_class.send(:looks_malicious?, "<body onload=alert('XSS')>")).to be_truthy
      expect(described_class.send(:looks_malicious?, '<svg onload="alert(1)">')).to be_truthy
    end

    it "detects SQL injection attempts" do
      expect(described_class.send(:looks_malicious?, "1' OR '1'='1")).to be_truthy
      expect(described_class.send(:looks_malicious?, "'; DROP TABLE users; --")).to be_truthy
      expect(described_class.send(:looks_malicious?, "1 UNION SELECT * FROM passwords")).to be_truthy
      expect(described_class.send(:looks_malicious?, "x'; DELETE FROM bikes WHERE 1=1; --")).to be_truthy
      expect(described_class.send(:looks_malicious?, "admin'; INSERT INTO users VALUES('a')--")).to be_truthy
      expect(described_class.send(:looks_malicious?, "ndbGRKFw')) OR 96=(SELECT 96 FROM PG_SLEEP(15))--")).to be_truthy
    end

    it "is false for benign words that brush against SQL tokens" do
      expect(described_class.send(:looks_malicious?, "Time to sleep (soon)")).to be_falsey
    end

    it "detects time-based blind SQL injection attempts" do
      expect(described_class.send(:looks_malicious?, "1-1 waitfor delay '0:0:15' --")).to be_truthy
      expect(described_class.send(:looks_malicious?, "1*if(now()=sysdate(),sleep(15),0)")).to be_truthy
      expect(described_class.send(:looks_malicious?, "1'||DBMS_PIPE.RECEIVE_MESSAGE(CHR(98)||CHR(98),15)||'")).to be_truthy
      expect(described_class.send(:looks_malicious?, "10\"XOR(1*if(now()=sysdate(),sleep(15),0))XOR\"Z")).to be_truthy
      expect(described_class.send(:looks_malicious?, "(select 198766*667891 from DUAL)")).to be_truthy
    end
  end

  describe "capital_count_suspiciousness" do
    let(:str) { "ABCABDEFGH" }
    it "returns 0" do
      expect(described_class.send(:capital_count_suspiciousness, "AAABBB")).to eq 0
      expect(described_class.send(:capital_count_suspiciousness, str.to_s)).to eq 15
      expect(described_class.send(:capital_count_suspiciousness, "#{str}f")).to be_between(5, 15)
    end

    it "returns 60 at most for 12 characters" do
      expect(described_class.send(:capital_count_suspiciousness, "#{str}AA")).to be_between(10, 20)
      expect(described_class.send(:capital_count_suspiciousness, "#{str}aa")).to be_between(5, 15)
      expect(described_class.send(:capital_count_suspiciousness, "AABBC DDeeaa")).to be_between(0, 5)
    end

    it "returns percentage for 25 characters" do
      expect(described_class.send(:capital_count_suspiciousness, "#{str}#{str}AABBC")).to be_between(25, 40)
      expect(described_class.send(:capital_count_suspiciousness, "#{str}#{str}aabbc")).to be_between(20, 30)
      expect(described_class.send(:capital_count_suspiciousness, "#{str}#{str} abbc")).to be_between(20, 30)
      expect(described_class.send(:capital_count_suspiciousness, "#{str} #{str} bbc")).to be_between(20, 30)
      expect(described_class.send(:capital_count_suspiciousness, "#{str}#{str.downcase}aabbc")).to be_between(5, 20)
      expect(described_class.send(:capital_count_suspiciousness, "#{str.downcase}#{str.downcase}AABBC")).to be_between(0, 5)
    end
  end
end
