require 'spec_helper'

describe Ctype do
  it_behaves_like 'friendly_slug_findable'
  describe 'validations' do
    it { is_expected.to belong_to :cgroup }
    it { is_expected.to have_many :components }
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_uniqueness_of :name }
  end
end
