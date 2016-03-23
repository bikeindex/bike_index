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
    it "removes Accell (because it's widespread mnfg)" do
      mnfg = FactoryGirl.create(:manufacturer, name: "Poopy PANTERS")
      Manufacturer.fuzzy_id_or_name_find('poopy panters Accell').should == mnfg
    end
  end

  describe 'autocomplete_hash_category' do
    context '0 bikes or components' do
      it 'returns 0' do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:bikes) { [] }
        allow(manufacturer).to receive(:components) { [] }
        expect(manufacturer.autocomplete_hash_priority).to eq(0)
      end
    end
    context '1 component' do
      it 'returns 10' do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:bikes) { [] }
        allow(manufacturer).to receive(:components) { [2] }
        expect(manufacturer.autocomplete_hash_priority).to eq(10)
      end
    end
    context '25 bikes and 50 components' do
      it 'returns 15' do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:bikes) { Array(0..24) }
        allow(manufacturer).to receive(:components) { Array(0..50) }
        expect(manufacturer.autocomplete_hash_priority).to eq(15)
      end
    end
    context '1020 bikes' do
      it 'returns 100' do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:bikes) { Array(1..1020) }
        allow(manufacturer).to receive(:components) { [2, 2, 2] }
        expect(manufacturer.autocomplete_hash_priority).to eq(100)
      end
    end
  end

  describe "import csv" do 
    it "adds manufacturers to the list" do
      import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import.csv")
      lambda {
        Manufacturer.import(import_file)
      }.should change(Manufacturer, :count).by(2)
    end
    
    it "adds in all the attributes that are listed" do 
      import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import.csv")
      Manufacturer.import(import_file)
      manufacturer = Manufacturer.find_by_slug("surly")
      manufacturer.website.should eq('http://surlybikes.com')
      manufacturer.frame_maker.should be_true
      manufacturer.open_year.should eq(1900)
      manufacturer.close_year.should eq(3000)
      manufacturer2 = Manufacturer.find_by_slug("wethepeople")
      manufacturer2.website.should eq('http://wethepeople.com')
    end

    it "updates attributes on a second upload" do 
      import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import.csv")
      Manufacturer.import(import_file)
      second_import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import-second.csv")
      Manufacturer.import(second_import_file)
      manufacturer = Manufacturer.find_by_slug("surly-bikes")
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

  describe :set_website_and_logo_source do 
    it "has before_save_callback_method defined for set_website" do
      Manufacturer._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_website_and_logo_source).should == true
    end

    it "sets logo source" do 
      manufacturer = Manufacturer.new
      manufacturer.stub(:logo).and_return('http://example.com/logo.png')
      manufacturer.set_website_and_logo_source
      manufacturer.logo_source.should eq('manual')
    end

    it "doesn't overwrite logo source" do 
      manufacturer = Manufacturer.new(logo_source: 'something cool')
      manufacturer.stub(:logo).and_return('http://example.com/logo.png')
      manufacturer.set_website_and_logo_source
      manufacturer.logo_source.should eq('something cool')
    end

    it "empties if no logo" do 
      manufacturer = Manufacturer.new(logo_source: 'something cool')
      manufacturer.set_website_and_logo_source
      manufacturer.logo_source.should be_nil
    end
  end

end
