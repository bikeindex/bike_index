require 'spec_helper'

describe FrontGearType do
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_presence_of :count }
    it { is_expected.to validate_uniqueness_of :name } 
  end
end
