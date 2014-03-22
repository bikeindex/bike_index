# encoding: utf-8
require 'spec_helper'

describe Slugifyer do
  describe :book_slug do 
    it "should remove special characters and downcase" do
      slug = Slugifyer.book_slug("Surly's Cross-check bike (small wheel)")
      slug.should eq("surly_s_cross_check_small_wheel")
    end

    it "should remove bikes and bicycles, because people just put them in everything" do 
      slug = Slugifyer.book_slug("Cross-check Singlespeed BicyclE")
      slug.should eq('cross_check_singlespeed')
    end

    it "should remove diacritics and bicycles, because people just put them in everything" do 
      slug = Slugifyer.book_slug('paké rum runner')
      slug.should eq('pake_rum_runner')
    end

    it "should change + to plus for URL safety, and Trek uses + to differentiate" do 
      slug = Slugifyer.book_slug("L100+ Lowstep BLX")
      slug.should eq('l100plus_lowstep_blx')
    end
  end

  describe :manufacturer do 
    it "should remove works rivendell" do 
      slug = Slugifyer.manufacturer("Rivendell Bicycle Works")
      slug.should eq('rivendell')      
    end
    it "should remove frameworks for legacy" do 
      slug = Slugifyer.manufacturer("Legacy Frameworks")
      slug.should eq('legacy')      
    end
    it "should remove bicycle company for Kona" do 
      slug = Slugifyer.manufacturer("Kona Bicycle Company")
      slug.should eq('kona')
    end
    it "should not remove WorkCycles" do 
      slug = Slugifyer.manufacturer("WorkCycles")
      slug.should eq('workcycles')
    end
    it "should not remove worksman" do 
      slug = Slugifyer.manufacturer("Worksman Cycles")
      slug.should eq('worksman')
    end
  end
  
end