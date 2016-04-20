require 'spec_helper'

describe OtherListing do
  describe 'validations' do
    it { is_expected.to validate_presence_of :bike_id }
    it { is_expected.to validate_presence_of :url }
    it { is_expected.to belong_to :bike }
  end
end
