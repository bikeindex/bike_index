require 'spec_helper'

describe AdminHelper do
  describe 'admin_display_date' do
    context 'today' do
      let(:target) { 'Today at 11:00am' }
      it 'returns today' do
        expect(admin_display_date(Time.now.beginning_of_day + 11.hours)).to eq target
      end
    end
    context 'yesterday' do
      let(:target) { 'Yesterday at 11:27pm' }
      it 'returns yesterday' do
        expect(admin_display_date(Time.now.yesterday.end_of_day - 32.minutes)).to eq target
      end
    end
    context 'other date' do
      let(:target) { '2/20/2017 at 1pm' }
      it 'returns in correct format' do
        expect(admin_display_date(Time.at(1487615859))).to eq target
      end
    end
  end
end
