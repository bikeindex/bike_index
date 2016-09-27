require 'spec_helper'

describe Location do
  describe 'validations' do
    it { is_expected.to belong_to :organization }
    it { is_expected.to belong_to :country }
    it { is_expected.to belong_to :state }
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_presence_of :organization_id }
    it { is_expected.to validate_presence_of :city }
    it { is_expected.to validate_presence_of :country_id }
  end

  describe 'set_phone' do
    it 'strips the non-digit numbers from the phone input' do
      location = FactoryGirl.create(:location, phone: '773.83ddp+83(887)')
      expect(location.phone).to eq('7738383887')
    end
  end

  describe 'address' do
    it 'strips the non-digit numbers from the phone input' do
      location = FactoryGirl.create(:location)
      expect(location.address).to be_a(String)
    end
    it 'creates an address' do
      c = Country.create(name: 'Neverland', iso: 'XXX')
      s = State.create(country_id: c.id, name: 'BullShit', abbreviation: 'XXX')
      location = FactoryGirl.create(:location, street: '300 Blossom Hill Dr', city: 'Lancaster', state_id: s.id, zipcode: '17601', country_id: c.id)
      expect(location.address).to eq('300 Blossom Hill Dr, Lancaster, XXX, 17601, Neverland')
    end
  end

  describe 'org_location_id' do
    it 'creates a unique id that references the organization' do
      location = FactoryGirl.create(:location)
      expect(location.org_location_id).to eq("#{location.organization_id}_#{location.id}")
    end
  end
end
