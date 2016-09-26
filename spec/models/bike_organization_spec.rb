require 'spec_helper'

RSpec.describe BikeOrganization, type: :model do
  describe 'validations' do
    it { is_expected.to belong_to :bike }
    it { is_expected.to belong_to :organization }
    it { is_expected.to validate_presence_of :bike_id }
    it { is_expected.to validate_presence_of :organization_id }
    it { is_expected.to validate_uniqueness_of(:organization_id).scoped_to(:bike_id) }
  end
end

