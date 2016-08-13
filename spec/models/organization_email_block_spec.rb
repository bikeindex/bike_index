require 'spec_helper'

RSpec.describe OrganizationEmailBlock, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of :organization_id }
    it { is_expected.to validate_presence_of :block_type }
    it { is_expected.to belong_to :organization }
    it { is_expected.to validate_uniqueness_of(:block_type).scoped_to(:organization_id) }
  end
end
