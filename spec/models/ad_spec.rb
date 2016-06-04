require 'spec_helper'

describe Ad do
  describe 'validations' do
    it { is_expected.to belong_to :organization }
    it { is_expected.to validate_presence_of :title }
    it { is_expected.to validate_uniqueness_of :title }
  end
end
