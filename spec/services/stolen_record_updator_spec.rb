require 'spec_helper'

describe StolenRecordUpdator do
  describe :create_new_record do 
    it "should create a new stolen record" do
      FactoryGirl.create(:country, iso: "US")
      bike = FactoryGirl.create(:bike)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      update_stolen_record.should_receive(:updated_phone).at_least(1).times.and_return("1231234444")
      lambda { update_stolen_record.create_new_record }.should change(StolenRecord, :count).by(1)
      bike.stolen_records.count.should eq(1)
    end

    it "should call mark_records_not_current" do 
      FactoryGirl.create(:country, iso: "US")
      bike = FactoryGirl.create(:bike, stolen: true)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      update_stolen_record.should_receive(:updated_phone).at_least(1).times.and_return("1231234444")
      update_stolen_record.should_receive(:mark_records_not_current)
      update_stolen_record.create_new_record
    end
  end

  describe :updated_phone do 
    it "should not set the phone if the user already has a phone" do 
      user = FactoryGirl.create(:user, phone: "0000000000")
      bike = Bike.new 
      bike.stub(:phone).and_return("699.999.9999")
      StolenRecordUpdator.new(bike: bike, user: user).updated_phone.should eq("699.999.9999")
      user.phone.should eq("0000000000")
    end

    it "should set the owner's phone if one is passed in" do 
      user = FactoryGirl.create(:user)
      bike = Bike.new
      bike.stub(:phone).and_return("699.999.9999")
      StolenRecordUpdator.new(bike: bike, user: user).updated_phone.should eq("699.999.9999")
      user.phone.should eq("6999999999")
    end
  end 
 
  describe :create_date_from_string do 
    it "should correctly translate a date string to a date_time" do 
      date_time = DateTime.strptime("07-09-2000 06", "%m-%d-%Y %H")
      bike = Bike.new
      u = StolenRecordUpdator.new(bike: bike)
      u.create_date_from_string("07-09-2000").should eq(date_time)
    end
  end

  describe :update_records do
    it "should set the current stolen record as not current if the bike isn't stolen" do 
      FactoryGirl.create(:country, iso: "US")
      bike = FactoryGirl.create(:bike, stolen: true)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      update_stolen_record.should_receive(:updated_phone).at_least(1).times.and_return("1231234444")
      update_stolen_record.should_receive(:mark_records_not_current)
      update_stolen_record.update_records
    end

    it "should call create if a stolen record doesn't exist doesn't exist" do 
      bike = FactoryGirl.create(:bike, stolen: true)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      update_stolen_record.should_receive(:create_new_record)
      update_stolen_record.update_records
    end

    it "should set the date if date_stolen is present" do 
      stolen_record = FactoryGirl.create(:stolen_record)
      bike = stolen_record.bike
      bike.update_attributes(stolen: true)
      StolenRecordUpdator.new(bike: bike, date_stolen_input: "01-01-1969").update_records
      bike.reload.current_stolen_record.date_stolen.should eq(DateTime.strptime("01-01-1969 06", "%m-%d-%Y %H"))
    end

    it "should mark all stolen records false and mark the bike unrecovered if the bike isn't stolen" do 
      bike = FactoryGirl.create(:bike, stolen: false, recovered: true)
      update_stolen_record = StolenRecordUpdator.new(bike: bike)
      update_stolen_record.should_receive(:mark_records_not_current)
      update_stolen_record.update_records
      bike.recovered.should be_false
    end
  end

  describe :mark_records_not_current do 
    it "should mark all the records not current" do 
      bike = FactoryGirl.create(:bike)
      stolen_record1 = FactoryGirl.create(:stolen_record, bike: bike)
      stolen_record2 = FactoryGirl.create(:stolen_record, bike: bike)
      stolen_record1.update_attributes(current: true)
      stolen_record2.update_attributes(current: true)
      StolenRecordUpdator.new(bike: bike).mark_records_not_current
      stolen_record1.reload.current.should be_false
      stolen_record2.reload.current.should be_false
    end
  end

  describe :set_creation_organization do 
    it "should set the creation organization from the bike" do 
      organization = FactoryGirl.create(:organization)
      bike = FactoryGirl.create(:bike, creation_organization_id: organization.id)
      stolen_record = FactoryGirl.create(:stolen_record, bike: bike)
      updated = StolenRecordUpdator.new(bike: bike).set_creation_organization
      stolen_record.reload.creation_organization.should eq(organization)
    end
  end


  describe :update_with_params do
    it "should return the stolen record if no stolen record is associated" do 
      stolen_record = StolenRecord.new 
      updator = StolenRecordUpdator.new().update_with_params(stolen_record)
      updator.should eq(stolen_record)
    end

    it "should set the data that is submitted" do 
      sr = { phone: '2123123',
        date_stolen: Time.now.beginning_of_day.strftime("%m-%d-%Y"),
        police_report_number: 'XXX',
        police_report_department: 'highway 69',
        theft_description: 'blah blah blah',
        street: 'some address',
        city: 'Big town',
        zipcode: '60666'
      }
      b_param = BParam.new
      b_param.stub(:params).and_return({stolen_record: sr})
      stolen_record = StolenRecord.new 
      updator = StolenRecordUpdator.new(new_bike_b_param: b_param)
      stolen_record = updator.update_with_params(stolen_record)
      stolen_record.police_report_number.should eq(sr[:police_report_number])
      stolen_record.police_report_department.should eq(sr[:police_report_department])
      stolen_record.theft_description.should eq(sr[:theft_description])
      stolen_record.street.should eq(sr[:street])
      stolen_record.city.should eq(sr[:city])
      stolen_record.zipcode.should eq('60666')
      stolen_record.date_stolen.today?.should be_true
    end

    it "should create the associations that it's suppose to" do
      country = FactoryGirl.create(:country)
      state = FactoryGirl.create(:state, country: country)
      sr = { state: state.abbreviation,
        country: country.iso
      }
      b_param = BParam.new
      b_param.stub(:params).and_return({stolen_record: sr})
      stolen_record = StolenRecord.new 
      updator = StolenRecordUpdator.new(new_bike_b_param: b_param)
      stolen_record = updator.update_with_params(stolen_record)
      stolen_record.country.should eq(country)
      stolen_record.state.should eq(state)
    end
  end


end
