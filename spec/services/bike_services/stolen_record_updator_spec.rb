require "rails_helper"

RSpec.describe BikeServices::StolenRecordUpdator do
  describe "update_records" do
    let(:bike) { FactoryBot.create(:bike) }
    it "does nothing" do
      expect(bike.reload.status).to eq "status_with_owner"
      stolen_record_updator = BikeServices::StolenRecordUpdator.new(bike: bike, b_param: BParam.new(params: {bike: {frame_material: "organic"}}))
      expect { stolen_record_updator.update_records }.to_not change(StolenRecord, :count)
      expect(bike.reload.status).to eq "status_with_owner"
    end
    context "date_stolen passed" do
      it "creates a stolen_record if passed date_stolen" do
        expect(bike.reload.status).to eq "status_with_owner"
        t = Time.current.to_s
        stolen_record_updator = BikeServices::StolenRecordUpdator.new(bike: bike, b_param: BParam.new(params: {bike: {date_stolen: t}}))
        expect(stolen_record_updator.stolen_params).to eq({"date_stolen" => t})
        # update_records creates a stolen record, because date_stolen is present
        expect { stolen_record_updator.update_records }.to change(StolenRecord, :count).by(1)
        expect(bike.reload.status).to eq "status_stolen"
      end
      context "existing stolen_record" do
        let(:stolen_record) { FactoryBot.create(:stolen_record) }
        let(:bike) { stolen_record.bike }
        it "sets the date" do
          expect(bike.reload.status).to eq "status_stolen"
          time = DateTime.strptime("01-01-1969 06", "%m-%d-%Y %H").end_of_day
          stolen_record_updator = BikeServices::StolenRecordUpdator.new(bike: bike, b_param: BParam.new(params: {bike: {date_stolen: time.to_i}}))
          expect(stolen_record_updator.stolen_params).to eq({"date_stolen" => time.to_i})
          expect { stolen_record_updator.update_records }.to_not change(StolenRecord, :count)
          expect(bike.reload.current_stolen_record.date_stolen).to be_within(1.second).of time
          expect(bike.current_stolen_record&.id).to eq stolen_record.id
        end
      end
    end
  end

  describe "update_with_params" do
    it "returns the stolen record if no stolen record is associated" do
      stolen_record = StolenRecord.new
      updator = BikeServices::StolenRecordUpdator.new.send(:update_with_params, stolen_record)
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
      b_param = BParam.new(params: {stolen_record: sr}.as_json)
      stolen_record = StolenRecord.new
      updator = BikeServices::StolenRecordUpdator.new(b_param: b_param)
      stolen_record = updator.send(:update_with_params, stolen_record)
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
      b_param = BParam.new(params: {stolen_record: sr}.as_json)
      stolen_record = StolenRecord.new
      updator = BikeServices::StolenRecordUpdator.new(b_param: b_param)
      stolen_record = updator.send(:update_with_params, stolen_record)
      expect(stolen_record.country).to eq(country)
      expect(stolen_record.state).to eq(state)
    end
  end
end
