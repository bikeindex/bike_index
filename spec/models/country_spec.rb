require 'spec_helper'

describe Country do
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :iso }
    it { is_expected.to validate_uniqueness_of :iso }
    it { is_expected.to have_many :stolen_records }
    it { is_expected.to have_many :locations }
  end

  describe 'fuzzy_iso_find' do
    it "finds the country by ISO address when the case doesn't match" do
      country = Country.create(name: 'EEEEEEEh', iso: 'LULZ')
      expect(Country.fuzzy_iso_find('lulz ')).to eq(country)
    end
    it 'finds USA' do
      country = Country.create(name: 'United States', iso: 'US')
      expect(Country.fuzzy_iso_find('USA')).to eq(country)
    end
  end
end
