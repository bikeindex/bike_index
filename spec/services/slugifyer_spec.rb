require "rails_helper"

RSpec.describe Slugifyer do
  describe "slugify" do
    it "handles &" do
      expect(Slugifyer.slugify("Bikes &amp; Trikes")).to eq "bikes-amp-trikes"
      expect(Slugifyer.slugify("Bikes & Trikes")).to eq "bikes-amp-trikes"
    end
    it "handles é" do
      expect(Slugifyer.slugify("paké rum runner")).to eq("pake-rum-runner")
      expect(Slugifyer.slugify("pañe rum runner")).to eq("pane-rum-runner")
    end

    it "removes parens" do
      expect(Slugifyer.slugify(" Some Cool NAMe (additional info)")).to eq("some-cool-name")
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

  describe "manufacturer" do
    it "removes works rivendell" do
      slug = Slugifyer.manufacturer("Rivendell Bicycle Works")
      expect(slug).to eq("rivendell")
    end
    it "removes frameworks for legacy" do
      slug = Slugifyer.manufacturer("Legacy Frameworks")
      expect(slug).to eq("legacy")
    end
    it "removes e-bike" do
      slug = Slugifyer.manufacturer("AIMA E-Bike")
      expect(slug).to eq("aima")
      expect(Slugifyer.manufacturer("AIMA EBike")).to eq "aima"
      expect(Slugifyer.manufacturer("AIMA E Bike")).to eq "aima"
    end
    it "removes electric bike" do
      slug = Slugifyer.manufacturer("Pedego Electric Bikes")
      expect(slug).to eq("pedego")
    end
    it "removes bicycle company for Kona" do
      slug = Slugifyer.manufacturer("Kona Bicycle Company")
      expect(slug).to eq("kona")
    end
    it "does not remove WorkCycles" do
      slug = Slugifyer.manufacturer("WorkCycles")
      expect(slug).to eq("workcycles")
    end
    it "does not remove haibike" do
      slug = Slugifyer.manufacturer("Haibike (Currietech)")
      expect(slug).to eq("haibike")
    end
    it "does not remove worksman" do
      slug = Slugifyer.manufacturer("Worksman Cycles")
      expect(slug).to eq("worksman")
    end
    it "removes parens from EAI" do
      slug = Slugifyer.manufacturer("EAI (Euro Asia Imports)")
      expect(slug).to eq("eai")
    end
    it "handles Riese & Müller (Riese and Muller)" do
      slug = Slugifyer.manufacturer("Riese & Müller (Riese and Muller)")
      expect(slug).to eq "riese_amp_muller"
    end
  end
end
