# encoding: utf-8
require 'spec_helper'

describe Slugifyer do
  describe :book_slug do 
    it "removes special characters and downcase" do
      slug = Slugifyer.book_slug("Surly's Cross-check bike (small wheel)")
      slug.should eq("surly_s_cross_check_small_wheel")
    end

    it "removes bikes and bicycles, because people just put them in everything" do 
      slug = Slugifyer.book_slug("Cross-check Singlespeed BicyclE")
      slug.should eq('cross_check_singlespeed')
    end

    it "removes diacritics and bicycles, because people just put them in everything" do 
      slug = Slugifyer.book_slug('paké rum runner')
      slug.should eq('pake_rum_runner')
    end

    it "changes + to plus for URL safety, and Trek uses + to differentiate" do 
      slug = Slugifyer.book_slug("L100+ Lowstep BLX")
      slug.should eq('l100plus_lowstep_blx')
    end
  end

  describe :manufacturer do 
    it "removes works rivendell" do 
      slug = Slugifyer.manufacturer("Rivendell Bicycle Works")
      slug.should eq('rivendell')      
    end
    it "removes frameworks for legacy" do 
      slug = Slugifyer.manufacturer("Legacy Frameworks")
      slug.should eq('legacy')      
    end
    it "removes bicycle company for Kona" do 
      slug = Slugifyer.manufacturer("Kona Bicycle Company")
      slug.should eq('kona')
    end
    it "does not remove WorkCycles" do 
      slug = Slugifyer.manufacturer("WorkCycles")
      slug.should eq('workcycles')
    end
    it "does not remove haibike" do 
      slug = Slugifyer.manufacturer("Haibike (Currietech)")
      slug.should eq('haibike')      
    end
    it "does not remove worksman" do 
      slug = Slugifyer.manufacturer("Worksman Cycles")
      slug.should eq('worksman')
    end
    it "removes parens from EAI" do 
      slug = Slugifyer.manufacturer("EAI (Euro Asia Imports)")
      slug.should eq('eai')
    end
  end
  
end
