require 'spec_helper'

describe StolenRecordUpdator do
  describe 'create_new_record' do
    it 'creates a new stolen record' do
      FactoryGirl.create(:country, iso: 'US')
      bike = FactoryGirl.create(:bike)
      update_stolenRecord = StolenRecordUpdator.new(bike: bike)
      expect(update_stolenRecord).to receive(:updated_phone).at_least(1).times.and_return('1231234444')
      expect { update_stolenRecord.create_new_record }.to change(StolenRecord, :count).by(1)
      expect(bike.stolenRecords.count).to eq(1)
      expect(bike.current_stolenRecord).to eq(bike.stolenRecords.last)
    end

    it 'calls mark_records_not_current' do
      FactoryGirl.create(:country, iso: 'US')
      bike = FactoryGirl.create(:bike, stolen: true)
      update_stolenRecord = StolenRecordUpdator.new(bike: bike)
      expect(update_stolenRecord).to receive(:updated_phone).at_least(1).times.and_return('1231234444')
      expect(update_stolenRecord).to receive(:mark_records_not_current)
      update_stolenRecord.create_new_record
    end
  end

  describe 'updated_phone' do
    it 'does not set the phone if the user already has a phone' do
      user = FactoryGirl.create(:user, phone: '0000000000')
      bike = Bike.new
      allow(bike).to receive(:phone).and_return('699.999.9999')
      expect(StolenRecordUpdator.new(bike: bike, user: user).updated_phone).to eq('699.999.9999')
      expect(user.phone).to eq('0000000000')
    end

    it "sets the owner's phone if one is passed in" do
      user = FactoryGirl.create(:user)
      bike = Bike.new
      allow(bike).to receive(:phone).and_return('699.999.9999')
      expect(StolenRecordUpdator.new(bike: bike, user: user).updated_phone).to eq('699.999.9999')
      expect(user.phone).to eq('6999999999')
    end
  end

  describe 'create_date_from_string' do
    it 'correctly translates a date string to a date_time' do
      date_time = DateTime.strptime('07-09-2000 06', '%m-%d-%Y %H')
      bike = Bike.new
      u = StolenRecordUpdator.new(bike: bike)
      expect(u.create_date_from_string('07-09-2000')).to eq(date_time)
    end
  end

  describe 'update_records' do
    it "sets the current stolen record as not current if the bike isn't stolen" do
      FactoryGirl.create(:country, iso: 'US')
      bike = FactoryGirl.create(:bike, stolen: true)
      update_stolenRecord = StolenRecordUpdator.new(bike: bike)
      expect(update_stolenRecord).to receive(:updated_phone).at_least(1).times.and_return('1231234444')
      expect(update_stolenRecord).to receive(:mark_records_not_current)
      update_stolenRecord.update_records
    end

    it "calls create if a stolen record doesn't exist" do
      bike = FactoryGirl.create(:bike, stolen: true)
      update_stolenRecord = StolenRecordUpdator.new(bike: bike)
      expect(update_stolenRecord).to receive(:create_new_record)
      update_stolenRecord.update_records
    end

    it 'sets the date if date_stolen is present' do
      stolenRecord = FactoryGirl.create(:stolenRecord)
      bike = stolenRecord.bike
      bike.update_attributes(stolen: true)
      StolenRecordUpdator.new(bike: bike, date_stolen_input: '01-01-1969').update_records
      expect(bike.reload.current_stolenRecord.date_stolen).to eq(DateTime.strptime('01-01-1969 06', '%m-%d-%Y %H'))
    end

    it "marks all stolen records false and mark the bike unrecovered if the bike isn't stolen" do
      bike = FactoryGirl.create(:bike, stolen: false, recovered: true)
      update_stolenRecord = StolenRecordUpdator.new(bike: bike)
      expect(update_stolenRecord).to receive(:mark_records_not_current)
      update_stolenRecord.update_records
      expect(bike.recovered).to be_falsey
    end
  end

  describe 'mark_records_not_current' do
    it 'marks all the records not current' do
      bike = FactoryGirl.create(:bike)
      stolenRecord1 = FactoryGirl.create(:stolenRecord, bike: bike)
      bike.save
      expect(bike.current_stolenRecord_id).to eq(stolenRecord1.id)
      stolenRecord2 = FactoryGirl.create(:stolenRecord, bike: bike)
      stolenRecord1.update_attributes(current: true)
      stolenRecord2.update_attributes(current: true)
      StolenRecordUpdator.new(bike: bike).mark_records_not_current
      expect(stolenRecord1.reload.current).to be_falsey
      expect(stolenRecord2.reload.current).to be_falsey
      expect(bike.reload.current_stolenRecord_id).to be_nil
    end
  end

  describe 'set_creation_organization' do
    it 'sets the creation organization from the bike' do
      organization = FactoryGirl.create(:organization)
      bike = FactoryGirl.create(:bike, creation_organization_id: organization.id)
      stolenRecord = FactoryGirl.create(:stolenRecord, bike: bike)
      updated = StolenRecordUpdator.new(bike: bike).set_creation_organization
      expect(stolenRecord.reload.creation_organization).to eq(organization)
    end
  end

  describe 'update_with_params' do
    it 'returns the stolen record if no stolen record is associated' do
      stolenRecord = StolenRecord.new
      updator = StolenRecordUpdator.new.update_with_params(stolenRecord)
      expect(updator).to eq(stolenRecord)
    end

    it 'sets the data that is submitted' do
      sr = { phone: '2123123',
             date_stolen: Time.now.beginning_of_day.strftime('%m-%d-%Y'),
             police_report_number: 'XXX',
             police_report_department: 'highway 69',
             theft_description: 'blah blah blah',
             street: 'some address',
             city: 'Big town',
             zipcode: '60666'
      }
      bikeParam = BParam.new
      allow(bikeParam).to receive(:params).and_return(stolenRecord: sr)
      stolenRecord = StolenRecord.new
      updator = StolenRecordUpdator.new(bikeParam: bikeParam.params)
      stolenRecord = updator.update_with_params(stolenRecord)
      expect(stolenRecord.police_report_number).to eq(sr[:police_report_number])
      expect(stolenRecord.police_report_department).to eq(sr[:police_report_department])
      expect(stolenRecord.theft_description).to eq(sr[:theft_description])
      expect(stolenRecord.street).to eq(sr[:street])
      expect(stolenRecord.city).to eq(sr[:city])
      expect(stolenRecord.zipcode).to eq('60666')
      expect(stolenRecord.date_stolen).to be > Time.now - 2.days
    end

    it "creates the associations that it's suppose to" do
      country = FactoryGirl.create(:country)
      state = FactoryGirl.create(:state, country: country)
      sr = { state: state.abbreviation,
             country: country.iso
      }
      bikeParam = BParam.new
      allow(bikeParam).to receive(:params).and_return(stolenRecord: sr)
      stolenRecord = StolenRecord.new
      updator = StolenRecordUpdator.new(bikeParam: bikeParam.params)
      stolenRecord = updator.update_with_params(stolenRecord)
      expect(stolenRecord.country).to eq(country)
      expect(stolenRecord.state).to eq(state)
    end
  end
end
