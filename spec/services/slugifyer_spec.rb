require "rails_helper"

RSpec.describe Slugifyer do
  describe "slugify" do
    it "handles &" do
      expect(Slugifyer.slugify("Bikes &amp; Trikes")).to eq "bikes-and-trikes"
      expect(Slugifyer.slugify("Bikes & Trikes")).to eq "bikes-and-trikes"
      expect(Slugifyer.slugify("B&B")).to eq "b-and-b"
      expect(Slugifyer.slugify("Bert's Bikes& Fitness")).to eq "berts-bikes-and-fitness"
    end
    it "handles + and HTML entities" do
      expect(Slugifyer.slugify("L100+ Lowstep")).to eq "l100-plus-lowstep"
      expect(Slugifyer.slugify("Heron Flats + Lofts")).to eq "heron-flats-plus-lofts"
      expect(Slugifyer.slugify("O&#39;Neil &quot;Bikes&quot;")).to eq "oneil-bikes"
    end
    it "drops apostrophes and separates on other punctuation" do
      expect(Slugifyer.slugify("Craig’s Cycles")).to eq "craigs-cycles"
      expect(Slugifyer.slugify("27.5")).to eq "27-5"
      expect(Slugifyer.slugify("Discus 45/40")).to eq "discus-45-40"
      expect(Slugifyer.slugify("e.bike")).to eq "e-bike"
      expect(Slugifyer.slugify("Italia_X")).to eq "italia-x"
    end
    it "squeezes and trims dashes" do
      expect(Slugifyer.slugify("Foo - Bar")).to eq "foo-bar"
      expect(Slugifyer.slugify("Trail / All-Mountain")).to eq "trail-all-mountain"
      expect(Slugifyer.slugify("(Old) Bicycle Security ...")).to eq "bicycle-security"
      expect(Slugifyer.slugify("foo---bar")).to eq "foo-bar"
    end
    it "handles é" do
      expect(Slugifyer.slugify("paké rum runner")).to eq("pake-rum-runner")
      expect(Slugifyer.slugify("pañe rum runner")).to eq("pane-rum-runner")
    end

    it "removes parens" do
      expect(Slugifyer.slugify(" Some Cool NAMe (additional info)")).to eq("some-cool-name")
    end
  end

  describe "amp_as_and" do
    it "converts an -amp- slug" do
      expect(Slugifyer.amp_as_and("bikes-and-trikes")).to be_nil
      expect(Slugifyer.amp_as_and("bikes-amp-trikes")).to eq "bikes-and-trikes"
    end
  end

  describe "broader_company_slugify" do
    it "removes works rivendell" do
      slug = Slugifyer.broader_company_slugify("Rivendell Bicycle Works")
      expect(slug).to eq("rivendell")
    end
    it "removes frameworks for legacy" do
      slug = Slugifyer.broader_company_slugify("Legacy Frameworks")
      expect(slug).to eq("legacy")
    end
    it "removes e-bike" do
      slug = Slugifyer.broader_company_slugify("AIMA E-Bike")
      expect(slug).to eq("aima")
      expect(Slugifyer.broader_company_slugify("AIMA EBike")).to eq "aima"
      expect(Slugifyer.broader_company_slugify("AIMA E Bike")).to eq "aima"
    end
    it "removes electric bike" do
      slug = Slugifyer.broader_company_slugify("Pedego Electric Bikes")
      expect(slug).to eq("pedego")
    end
    it "removes bicycle company for Kona" do
      slug = Slugifyer.broader_company_slugify("Kona Bicycle Company")
      expect(slug).to eq("kona")
    end
    it "does not remove WorkCycles" do
      slug = Slugifyer.broader_company_slugify("WorkCycles")
      expect(slug).to eq("workcycles")
    end
    it "does not remove haibike" do
      slug = Slugifyer.broader_company_slugify("Haibike (Currietech)")
      expect(slug).to eq("haibike")
    end
    it "does not remove worksman" do
      slug = Slugifyer.broader_company_slugify("Worksman Cycles")
      expect(slug).to eq("worksman")
    end
    it "removes parens from EAI" do
      slug = Slugifyer.broader_company_slugify("EAI (Euro Asia Imports)")
      expect(slug).to eq("eai")
    end
    it "handles Riese & Müller (Riese and Muller)" do
      slug = Slugifyer.broader_company_slugify("Riese & Müller (Riese and Muller)")
      expect(slug).to eq "riese_amp_muller"
    end
    it "removes accell" do
      expect(Slugifyer.broader_company_slugify("Poopy Panters Accell")).to eq "poopy_panters"
      expect(Slugifyer.broader_company_slugify("Accell")).to eq "accell"
    end
    it "keeps the suffix when removing it would leave only digits" do
      expect(Slugifyer.broader_company_slugify("101 Bikes")).to eq "101_bikes"
      expect(Slugifyer.broader_company_slugify("101_bikes")).to eq "101_bikes"
      expect(Slugifyer.broader_company_slugify("101 Electric Bikes (Other Name)")).to eq "101_electric_bikes"
      expect(Slugifyer.broader_company_slugify("22 Bicycle Co.")).to eq "22_bicycle"
      expect(Slugifyer.broader_company_slugify("24 Seven Bikes")).to eq "24_seven"
    end
  end
end
