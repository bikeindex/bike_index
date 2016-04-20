require 'spec_helper'

describe PropulsionType do
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :name }  
  end
end
