require 'spec_helper'

describe Cgroup do
  it_behaves_like 'friendly_slug_findable'
  describe 'validations' do
    it { is_expected.to have_many :ctypes }
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :name }
  end

  describe 'additional_parts' do
    it 'finds additional parts' do
      expect(Cgroup.additional_parts.name).to eq 'Additional parts'
    end
  end
end
