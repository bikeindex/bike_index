require 'rails_helper'

RSpec.describe LocationSchedule, type: :model do
  describe "closed_on?" do
    let(:location) { FactoryBot.create(:location) }
    before { location.fetch_reference_location_schedules }
    it "is true when no location_schedule" do
      expect(location.closed_on?("Tuesday")).to be_truthy
      next_tuesday = (Date.today..(Date.today + 1.week)).find { |d| d.wday == 2 }
      expect(LocationSchedule.to_weekday(next_tuesday)).to eq "tuesday"
      expect(location.closed_on?(next_tuesday)).to be_truthy
    end
    describe "with reference_location_schedule" do
      let(:next_wednesday) do
        date = Date.parse("wednesday")
        delta = date > Date.today ? 0 : 7
        date + delta
      end
      it "is true when reference_location_schedule has no hours" do
        location_schedule_wednesday = location.reference_location_schedules.wednesday.first
        location_schedule_wednesday.update_attributes(schedule: { hours: [9,16] })
        expect(location_schedule_wednesday.closed?).to be_falsey
        expect(LocationSchedule.to_weekday("Wednesday")).to eq "wednesday"
        expect(LocationSchedule.to_weekday(next_wednesday)).to eq "wednesday"
        expect(LocationSchedule.to_weekday(next_wednesday.beginning_of_day + 4.hours)).to eq "wednesday"
        next_wednesday_schedule = location.location_schedules.create(date: next_wednesday, set_closed: true, schedule: { hours: [22, 16] })
        expect(next_wednesday_schedule.closed?).to be_truthy
        expect(location.closed_on?("Wednesday ")).to be_falsey
        expect(location.closed_on?(next_wednesday)).to be_truthy
      end
    end
  end
end
