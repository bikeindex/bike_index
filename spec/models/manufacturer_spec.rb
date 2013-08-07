require 'spec_helper'

describe Manufacturer do
  describe "import csv" do 
    it "should add manufacturers to the list" do
      import_file = File.open(Rails.root.to_s + "/spec/manufacturer-test-import.csv")
      lambda {
        Manufacturer.import(import_file)
      }.should change(Manufacturer, :count).by(2)
    end
    
    it "should add in all the attributes that are listed" do 
      import_file = File.open(Rails.root.to_s + "/spec/manufacturer-test-import.csv")
      Manufacturer.import(import_file)
      @manufacturer = Manufacturer.find_by_slug("surly-bikes")
      @manufacturer.website.should eq('http://surlybikes.com')
      @manufacturer.frame_maker.should be_true
      @manufacturer.open_year.should eq(1900)
      @manufacturer.close_year.should eq(3000)
      @manufacturer.logo_location.should eq('http://example.com')
      @manufacturer2 = Manufacturer.find_by_slug("wethepeople")
      @manufacturer2.website.should eq('http://wethepeople.com')
    end

    it "should update attributes on a second upload" do 
      import_file = File.open(Rails.root.to_s + "/spec/manufacturer-test-import.csv")
      Manufacturer.import(import_file)
      second_import_file = File.open(Rails.root.to_s + "/spec/manufacturer-test-import-second.csv")
      Manufacturer.import(second_import_file)
      @manufacturer = Manufacturer.find_by_slug("surly-bikes")
      @manufacturer.logo_location.should eq('http://NEWTHING.com')

    end

  end

end