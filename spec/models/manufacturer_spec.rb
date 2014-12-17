require 'spec_helper'

describe Manufacturer do
  describe :validations do 
    it { should validate_presence_of :name }
    it { should validate_uniqueness_of :name }
    xit { should validate_uniqueness_of :slug }
    it { should have_many :bikes }
    it { should have_many :locks }
    it { should have_many :components }
    it { should have_many :paints }
  end


  describe :fuzzy_name_find do
    it "finds manufacturers by their slug" do
      mnfg = FactoryGirl.create(:manufacturer, name: "Poopy PANTERS")
      Manufacturer.fuzzy_name_find('poopy panters').should == mnfg
    end
  end

  describe "import csv" do 
    it "adds manufacturers to the list" do
      import_file = File.open(Rails.root.to_s + "/spec/manufacturer-test-import.csv")
      lambda {
        Manufacturer.import(import_file)
      }.should change(Manufacturer, :count).by(2)
    end
    
    it "adds in all the attributes that are listed" do 
      import_file = File.open(Rails.root.to_s + "/spec/manufacturer-test-import.csv")
      Manufacturer.import(import_file)
      @manufacturer = Manufacturer.find_by_slug("surly")
      @manufacturer.website.should eq('http://surlybikes.com')
      @manufacturer.frame_maker.should be_true
      @manufacturer.open_year.should eq(1900)
      @manufacturer.close_year.should eq(3000)
      @manufacturer2 = Manufacturer.find_by_slug("wethepeople")
      @manufacturer2.website.should eq('http://wethepeople.com')
    end

    it "updates attributes on a second upload" do 
      import_file = File.open(Rails.root.to_s + "/spec/manufacturer-test-import.csv")
      Manufacturer.import(import_file)
      second_import_file = File.open(Rails.root.to_s + "/spec/manufacturer-test-import-second.csv")
      Manufacturer.import(second_import_file)
      @manufacturer = Manufacturer.find_by_slug("surly-bikes")
    end
  end

  describe :fuzzy_id do 
    it "gets id from name" do 
      manufacturer = FactoryGirl.create(:manufacturer)
      result = Manufacturer.fuzzy_id(manufacturer.name)
      result.should eq(manufacturer.id)
    end
    it "fails with nil" do 
      result = Manufacturer.fuzzy_id('some stuff')
      result.should be_nil
    end
  end

  describe :sm_options do 
    it "creates a hash for soulmate, and counts components if all is true" do 
      manufacturer = FactoryGirl.create(:manufacturer)
      component = FactoryGirl.create(:component, manufacturer_id: manufacturer.id)
      bike = FactoryGirl.create(:bike, manufacturer_id: manufacturer.id)
      target = {
        id: manufacturer.id,
        term: manufacturer.name,
        score: 1,
        data: {}
      }
      result = manufacturer.sm_options
      result.should eq(target)
      target[:score] = 2
      result_all = manufacturer.sm_options(true)
      result_all.should eq(target)
    end
  end

  it "has before_save_callback_method defined for set_website" do
    Manufacturer._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_website).should == true
  end

end
