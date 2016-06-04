require 'spec_helper'
describe Membership do
  describe 'admin?' do
    context 'admin' do
      it 'returns true' do
        membership = Membership.new(role: 'admin')
        expect(membership.admin?).to be_true
      end
    end
    context 'member' do
      it 'returns true' do
        membership = Membership.new(role: 'member')
        expect(membership.admin?).to be_false
      end
    end
  end
end
