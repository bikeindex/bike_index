require "rails_helper"

RSpec.describe StolenRecordUpdator do
  describe "create_new_record" do
    it "creates a new stolen record" do
      bike = FactoryBot.create(:bike)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      expect { update_stolen_record.create_new_record }.to change(StolenRecord, :count).by(1)
      bike.reload
      expect(bike.stolen_records.count).to eq(1)
      expect(bike.current_stolen_record).to eq(bike.stolen_records.last)
    end
  end

  describe "update_records" do
    it "calls create if a stolen record doesn't exist" do
      bike = FactoryBot.create(:bike, stolen: true)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      expect(update_stolen_record).to receive(:create_new_record)
      update_stolen_record.update_records
    end

    it "sets the date if date_stolen is present" do
      stolen_record = FactoryBot.create(:stolen_record)
      bike = stolen_record.bike
      bike.update_attributes(stolen: true)
      time = DateTime.strptime("01-01-1969 06", "%m-%d-%Y %H").end_of_day
      StolenRecordUpdator.new(bike: bike, date_stolen: time.to_i).update_records
      expect(bike.reload.current_stolen_record.date_stolen).to be_within(1.second).of time
    end
  end

  describe "update_with_params" do
    it "returns the stolen record if no stolen record is associated" do
      stolen_record = StolenRecord.new
      updator = StolenRecordUpdator.new.send("update_with_params", stolen_record)
      expect(updator).to eq(stolen_record)
    end

    it "sets the data that is submitted" do
      time = "2018-07-27T11:41:41.484"
      target_time = 1532659301
      sr = {
        phone: "2123123",
        date_stolen: time,
        timezone: "Asia/Tokyo",
        police_report_number: "XXX",
        police_report_department: "highway 69",
        theft_description: "blah blah blah",
        street: "some address",
        city: "Big town",
        zipcode: "60666"
      }
      b_param = BParam.new
      allow(b_param).to receive(:params).and_return({stolen_record: sr}.as_json)
      stolen_record = StolenRecord.new
      updator = StolenRecordUpdator.new(b_param: b_param.params)
      stolen_record = updator.send("update_with_params", stolen_record)
      expect(stolen_record.police_report_number).to eq(sr[:police_report_number])
      expect(stolen_record.police_report_department).to eq(sr[:police_report_department])
      expect(stolen_record.theft_description).to eq(sr[:theft_description])
      expect(stolen_record.street).to eq(sr[:street])
      expect(stolen_record.city).to eq(sr[:city])
      expect(stolen_record.zipcode).to eq("60666")
      expect(stolen_record.date_stolen.to_i).to be_within(1).of target_time
    end

    it "creates the associations that it's suppose to" do
      country = FactoryBot.create(:country)
      state = FactoryBot.create(:state, country: country)
      sr = {
        state: state.abbreviation,
        country: country.iso
      }
      b_param = BParam.new
      allow(b_param).to receive(:params).and_return({stolen_record: sr}.as_json)
      stolen_record = StolenRecord.new
      updator = StolenRecordUpdator.new(b_param: b_param.params)
      stolen_record = updator.send("update_with_params", stolen_record)
      expect(stolen_record.country).to eq(country)
      expect(stolen_record.state).to eq(state)
    end
  end
end
