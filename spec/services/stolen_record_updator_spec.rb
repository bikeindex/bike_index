require 'spec_helper'

describe StolenRecordUpdator do
  describe 'create_new_record' do
    it 'creates a new stolen record' do
      FactoryGirl.create(:country, iso: 'US')
      bike = FactoryGirl.create(:bike)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      expect(update_stolen_record).to receive(:updated_phone).at_least(1).times.and_return('1231234444')
      expect { update_stolen_record.create_new_record }.to change(StolenRecord, :count).by(1)
      expect(bike.stolen_records.count).to eq(1)
      expect(bike.current_stolen_record).to eq(bike.stolen_records.last)
    end

    it 'calls mark_records_not_current' do
      FactoryGirl.create(:country, iso: 'US')
      bike = FactoryGirl.create(:bike, stolen: true)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      expect(update_stolen_record).to receive(:updated_phone).at_least(1).times.and_return('1231234444')
      expect(update_stolen_record).to receive(:mark_records_not_current)
      update_stolen_record.create_new_record
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
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      expect(update_stolen_record).to receive(:updated_phone).at_least(1).times.and_return('1231234444')
      expect(update_stolen_record).to receive(:mark_records_not_current)
      update_stolen_record.update_records
    end

    it "calls create if a stolen record doesn't exist" do
      bike = FactoryGirl.create(:bike, stolen: true)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      expect(update_stolen_record).to receive(:create_new_record)
      update_stolen_record.update_records
    end

    it 'sets the date if date_stolen is present' do
      stolen_record = FactoryGirl.create(:stolen_record)
      bike = stolen_record.bike
      bike.update_attributes(stolen: true)
      StolenRecordUpdator.new(bike: bike, date_stolen_input: '01-01-1969').update_records
      expect(bike.reload.current_stolen_record.date_stolen).to eq(DateTime.strptime('01-01-1969 06', '%m-%d-%Y %H'))
    end

    it "marks all stolen records false and mark the bike unrecovered if the bike isn't stolen" do
      bike = FactoryGirl.create(:bike, stolen: false, recovered: true)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      expect(update_stolen_record).to receive(:mark_records_not_current)
      update_stolen_record.update_records
      expect(bike.recovered).to be_falsey
    end
  end

  describe 'mark_records_not_current' do
    it 'marks all the records not current' do
      bike = FactoryGirl.create(:bike)
      stolen_record1 = FactoryGirl.create(:stolen_record, bike: bike)
      bike.save
      expect(bike.current_stolen_record_id).to eq(stolen_record1.id)
      stolen_record2 = FactoryGirl.create(:stolen_record, bike: bike)
      stolen_record1.update_attributes(current: true)
      stolen_record2.update_attributes(current: true)
      StolenRecordUpdator.new(bike: bike).mark_records_not_current
      expect(stolen_record1.reload.current).to be_falsey
      expect(stolen_record2.reload.current).to be_falsey
      expect(bike.reload.current_stolen_record_id).to be_nil
    end
  end

  describe 'set_creation_organization' do
    it 'sets the creation organization from the bike' do
      organization = FactoryGirl.create(:organization)
      bike = FactoryGirl.create(:bike, creation_organization_id: organization.id)
      stolen_record = FactoryGirl.create(:stolen_record, bike: bike)
      updated = StolenRecordUpdator.new(bike: bike).set_creation_organization
      expect(stolen_record.reload.creation_organization).to eq(organization)
    end
  end

  describe 'update_with_params' do
    it 'returns the stolen record if no stolen record is associated' do
      stolen_record = StolenRecord.new
      updator = StolenRecordUpdator.new.update_with_params(stolen_record)
      expect(updator).to eq(stolen_record)
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
      b_param = BParam.new
      allow(b_param).to receive(:params).and_return(stolen_record: sr)
      stolen_record = StolenRecord.new
      updator = StolenRecordUpdator.new(b_param: b_param.params)
      stolen_record = updator.update_with_params(stolen_record)
      expect(stolen_record.police_report_number).to eq(sr[:police_report_number])
      expect(stolen_record.police_report_department).to eq(sr[:police_report_department])
      expect(stolen_record.theft_description).to eq(sr[:theft_description])
      expect(stolen_record.street).to eq(sr[:street])
      expect(stolen_record.city).to eq(sr[:city])
      expect(stolen_record.zipcode).to eq('60666')
      expect(stolen_record.date_stolen).to be > Time.now - 2.days
    end

    it "creates the associations that it's suppose to" do
      country = FactoryGirl.create(:country)
      state = FactoryGirl.create(:state, country: country)
      sr = { state: state.abbreviation,
             country: country.iso
      }
      b_param = BParam.new
      allow(b_param).to receive(:params).and_return(stolen_record: sr)
      stolen_record = StolenRecord.new
      updator = StolenRecordUpdator.new(b_param: b_param.params)
      stolen_record = updator.update_with_params(stolen_record)
      expect(stolen_record.country).to eq(country)
      expect(stolen_record.state).to eq(state)
    end
  end
end
