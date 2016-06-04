require 'spec_helper'
describe Membership do
  describe 'validations' do
    it { is_expected.to belong_to :organization }
    it { is_expected.to belong_to(:user).touch(true) }
    it { is_expected.to validate_presence_of(:role).with_message(/a role/i) }
    it { is_expected.to validate_presence_of(:organization).with_message(/organization/i) }
    it { is_expected.to validate_presence_of(:user).with_message(/user/) }
  end

  describe 'admin?' do
    context 'admin' do
      it 'returns true' do
        membership = Membership.new(role: 'admin')
        expect(membership.admin?).to be_truthy
      end
    end
    context 'member' do
      it 'returns true' do
        membership = Membership.new(role: 'member')
        expect(membership.admin?).to be_falsey
      end
    end
  end
end
