require 'spec_helper'

describe Manufacturer do
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :name }
    xit { is_expected.to validate_uniqueness_of :slug }
    it { is_expected.to have_many :bikes }
    it { is_expected.to have_many :locks }
    it { is_expected.to have_many :components }
    it { is_expected.to have_many :paints }
  end

  describe 'ensure_non_blocking_name' do
    before { FactoryGirl.create(:color, name: 'Purple') }
    context 'name same as a color' do
      it 'adds an error' do
        manufacturer = FactoryGirl.build(:manufacturer, name: ' pURple ')
        manufacturer.valid?
        expect(manufacturer.errors.full_messages.to_s).to match 'same as a color'
      end
    end
    context 'name includes a color' do
      it 'adds no error' do
        manufacturer = FactoryGirl.build(:manufacturer, name: 'Purple bikes')
        manufacturer.valid?
        expect(manufacturer.errors.count).to eq 0
      end
    end
  end

  describe 'fuzzy_name_find' do
    it 'finds manufacturers by their slug' do
      mnfg = FactoryGirl.create(:manufacturer, name: 'Poopy PANTERS')
      expect(Manufacturer.fuzzy_name_find('poopy panters')).to eq(mnfg)
    end
    it "removes Accell (because it's widespread mnfg)" do
      mnfg = FactoryGirl.create(:manufacturer, name: 'Poopy PANTERS')
      expect(Manufacturer.fuzzy_id_or_name_find('poopy panters Accell')).to eq(mnfg)
    end
  end

  describe 'autocomplete_hash' do
    it 'returns what we expect' do
      manufacturer = FactoryGirl.create(:manufacturer)
      result = manufacturer.autocomplete_hash
      expect(result.keys).to eq(%w(id text category priority data))
      expect(result['data']['slug']).to eq manufacturer.slug
      expect(result['data']['search_id']).to eq("m_#{manufacturer.id}")
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

  describe 'import csv' do
    it 'adds manufacturers to the list' do
      import_file = File.open(Rails.root.to_s + '/spec/fixtures/manufacturer-test-import.csv')
      expect do
        Manufacturer.import(import_file)
      end.to change(Manufacturer, :count).by(2)
    end

    it 'adds in all the attributes that are listed' do
      import_file = File.open(Rails.root.to_s + '/spec/fixtures/manufacturer-test-import.csv')
      Manufacturer.import(import_file)
      manufacturer = Manufacturer.find_by_slug('surly')
      expect(manufacturer.website).to eq('http://surlybikes.com')
      expect(manufacturer.frame_maker).to be_truthy
      expect(manufacturer.open_year).to eq(1900)
      expect(manufacturer.close_year).to eq(3000)
      manufacturer2 = Manufacturer.find_by_slug('wethepeople')
      expect(manufacturer2.website).to eq('http://wethepeople.com')
    end

    it 'updates attributes on a second upload' do
      import_file = File.open(Rails.root.to_s + '/spec/fixtures/manufacturer-test-import.csv')
      Manufacturer.import(import_file)
      second_import_file = File.open(Rails.root.to_s + '/spec/fixtures/manufacturer-test-import-second.csv')
      Manufacturer.import(second_import_file)
      manufacturer = Manufacturer.find_by_slug('surly-bikes')
    end
  end

  describe 'fuzzy_id' do
    it 'gets id from name' do
      manufacturer = FactoryGirl.create(:manufacturer)
      result = Manufacturer.fuzzy_id(manufacturer.name)
      expect(result).to eq(manufacturer.id)
    end
    it 'fails with nil' do
      result = Manufacturer.fuzzy_id('some stuff')
      expect(result).to be_nil
    end
  end

  describe 'set_website_and_logo_source' do
    it 'has before_save_callback_method defined for set_website' do
      expect(Manufacturer._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_website_and_logo_source)).to eq(true)
    end

    it 'sets logo source' do
      manufacturer = Manufacturer.new
      allow(manufacturer).to receive(:logo).and_return('http://example.com/logo.png')
      manufacturer.set_website_and_logo_source
      expect(manufacturer.logo_source).to eq('manual')
    end

    it "doesn't overwrite logo source" do
      manufacturer = Manufacturer.new(logo_source: 'something cool')
      allow(manufacturer).to receive(:logo).and_return('http://example.com/logo.png')
      manufacturer.set_website_and_logo_source
      expect(manufacturer.logo_source).to eq('something cool')
    end

    it 'empties if no logo' do
      manufacturer = Manufacturer.new(logo_source: 'something cool')
      manufacturer.set_website_and_logo_source
      expect(manufacturer.logo_source).to be_nil
    end
  end
end
