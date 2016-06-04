require 'spec_helper'

describe Listicle do
  describe 'validations' do
    it { is_expected.to belong_to :blog }
  end
end
