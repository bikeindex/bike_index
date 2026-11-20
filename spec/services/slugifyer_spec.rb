require "rails_helper"

RSpec.describe Slugifyer do
  describe "slugify" do
    it "handles &" do
      expect(Slugifyer.slugify("Bikes &amp; Trikes")).to eq "bikes_amp_trikes"
      expect(Slugifyer.slugify("Bikes & Trikes")).to eq "bikes_amp_trikes"
    end
    it "turns dashes into underscores" do
      expect(Slugifyer.slugify("All-City_Cycles")).to eq "all_city_cycles"
      expect(Slugifyer.slugify("bikes-amp-trikes")).to eq "bikes_amp_trikes"
    end
    it "handles é" do
      expect(Slugifyer.slugify("paké rum runner")).to eq("pake_rum_runner")
      expect(Slugifyer.slugify("pañe rum runner")).to eq("pane_rum_runner")
    end

    it "removes parens" do
      expect(Slugifyer.slugify(" Some Cool NAMe (additional info)")).to eq("some_cool_name")
    end
  end

  describe "same_slug?" do
    it "ignores dashes" do
      expect(Slugifyer.same_slug?("bike-shop-2", "bike_shop_2")).to be_truthy
      expect(Slugifyer.same_slug?(nil, "bike_shop")).to be_falsey
    end
  end

  describe "lookup_slugs" do
    it "includes the dashed slug" do
      expect(Slugifyer.lookup_slugs("Some Cool-Name")).to eq %w[some_cool_name some-cool-name]
      expect(Slugifyer.lookup_slugs("cool")).to eq %w[cool]
    end
  end

  describe "book_slug" do
    it "removes special characters and downcase" do
      slug = Slugifyer.book_slug("Surly's Cross-check bike (small wheel)")
      expect(slug).to eq("surly_s_cross_check_small_wheel")
    end

    it "removes bikes and bicycles, because people just put them in everything" do
      slug = Slugifyer.book_slug("Cross-check Singlespeed BicyclE")
      expect(slug).to eq("cross_check_singlespeed")
    end

    it "removes diacritics and bicycles, because people just put them in everything" do
      slug = Slugifyer.book_slug("paké rum runner")
      expect(slug).to eq("pake_rum_runner")
    end

    it "changes + to plus for URL safety, and Trek uses + to differentiate" do
      slug = Slugifyer.book_slug("L100+ Lowstep BLX")
      expect(slug).to eq("l100plus_lowstep_blx")
    end
  end

  describe "legacy_manufacturer" do
    it "removes works rivendell" do
      slug = Slugifyer.legacy_manufacturer("Rivendell Bicycle Works")
      expect(slug).to eq("rivendell")
    end
    it "removes frameworks for legacy" do
      slug = Slugifyer.legacy_manufacturer("Legacy Frameworks")
      expect(slug).to eq("legacy")
    end
    it "removes e-bike" do
      slug = Slugifyer.legacy_manufacturer("AIMA E-Bike")
      expect(slug).to eq("aima")
      expect(Slugifyer.legacy_manufacturer("AIMA EBike")).to eq "aima"
      expect(Slugifyer.legacy_manufacturer("AIMA E Bike")).to eq "aima"
    end
    it "removes electric bike" do
      slug = Slugifyer.legacy_manufacturer("Pedego Electric Bikes")
      expect(slug).to eq("pedego")
    end
    it "removes bicycle company for Kona" do
      slug = Slugifyer.legacy_manufacturer("Kona Bicycle Company")
      expect(slug).to eq("kona")
    end
    it "does not remove WorkCycles" do
      slug = Slugifyer.legacy_manufacturer("WorkCycles")
      expect(slug).to eq("workcycles")
    end
    it "does not remove haibike" do
      slug = Slugifyer.legacy_manufacturer("Haibike (Currietech)")
      expect(slug).to eq("haibike")
    end
    it "does not remove worksman" do
      slug = Slugifyer.legacy_manufacturer("Worksman Cycles")
      expect(slug).to eq("worksman")
    end
    it "removes parens from EAI" do
      slug = Slugifyer.legacy_manufacturer("EAI (Euro Asia Imports)")
      expect(slug).to eq("eai")
    end
    it "handles Riese & Müller (Riese and Muller)" do
      slug = Slugifyer.legacy_manufacturer("Riese & Müller (Riese and Muller)")
      expect(slug).to eq "riese_amp_muller"
    end
    it "removes accell" do
      expect(Slugifyer.legacy_manufacturer("Poopy Panters Accell")).to eq "poopy_panters"
      expect(Slugifyer.legacy_manufacturer("Accell")).to eq "accell"
    end
    it "keeps the suffix when removing it would leave only digits" do
      expect(Slugifyer.legacy_manufacturer("101 Bikes")).to eq "101_bikes"
      expect(Slugifyer.legacy_manufacturer("101_bikes")).to eq "101_bikes"
      expect(Slugifyer.legacy_manufacturer("101 Electric Bikes (Other Name)")).to eq "101_electric_bikes"
      expect(Slugifyer.legacy_manufacturer("22 Bicycle Co.")).to eq "22_bicycle"
      expect(Slugifyer.legacy_manufacturer("24 Seven Bikes")).to eq "24_seven"
    end
  end
end
