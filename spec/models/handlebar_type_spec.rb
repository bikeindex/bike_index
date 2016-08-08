require 'spec_helper'

describe HandlebarType do
  it_behaves_like 'friendly_slug_findable'
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :name }
    it { is_expected.to validate_presence_of :slug }
  end
end
