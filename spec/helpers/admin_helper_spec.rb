require 'spec_helper'

describe AdminHelper do
  describe 'admin_display_date' do
    let(:time_now_in_zone) { Time.now.in_time_zone('Central Time (US & Canada)') }
    context 'today' do
      let(:target) { 'Today at 11:00am' }
      it 'returns today' do
        expect(admin_display_date(time_now_in_zone.beginning_of_day.in_time_zone('Central Time (US & Canada)') + 11.hours)).to eq target
      end
    end
    context 'yesterday' do
      let(:target) { 'Yesterday at 11:27pm' }
      it 'returns yesterday' do
        expect(admin_display_date(time_now_in_zone.yesterday.end_of_day - 32.minutes)).to eq target
      end
    end
    context 'other date' do
      let(:target) { '2/20/2017 at 10am' }
      let(:time) { Time.parse('2017-02-20T10:37:39.000-06:00') }
      it 'returns in correct format' do
        expect(Time.zone.name).to eq 'Central Time (US & Canada)'
        expect(admin_display_date(time)).to eq target
      end
    end
  end
end
