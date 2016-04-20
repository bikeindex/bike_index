require 'spec_helper'

describe StolenRecord do
  
  describe :validations do 
    it { should validate_presence_of :bike }
    it { should validate_presence_of :date_stolen }
    it { should belong_to :bike }
    it { should have_one :recovery_display }
    it { should belong_to :country }
    it { should belong_to :state }
    it { should belong_to :creation_organization }
  end

  it "marks current true by default" do 
    stolen_record = StolenRecord.new
    stolen_record.current.should be_true
  end

  describe :scopes do 
    it "default scopes to current" do 
      StolenRecord.scoped.to_sql.should == StolenRecord.where(current: true).to_sql
    end
    it "scopes approveds" do 
      StolenRecord.approveds.to_sql.should == StolenRecord.where(current: true).where(approved: true).to_sql
    end
    it "scopes approveds_with_reports" do 
      StolenRecord.approveds_with_reports.to_sql.should == StolenRecord.where(current: true).where(approved: true).
        where("police_report_number IS NOT NULL").where("police_report_department IS NOT NULL").to_sql
    end
    
    it "scopes not_tsved" do 
      StolenRecord.not_tsved.to_sql.should == StolenRecord.where(current: true).where("tsved_at IS NULL").to_sql
    end
    it "scopes recovered" do 
      StolenRecord.recovered.to_sql.should == StolenRecord.unscoped.where(current: false).order("date_recovered desc").to_sql
    end
    it "scopes displayable" do 
      StolenRecord.displayable.to_sql.should == StolenRecord.unscoped.where(current: false, can_share_recovery: true).order("date_recovered desc").to_sql
    end
    it "scopes recovery_unposted" do 
      StolenRecord.recovery_unposted.to_sql.should == StolenRecord.unscoped.where(current: false, recovery_posted: false).to_sql
    end
    it "scopes tsv_today" do 
      stolen1 = FactoryGirl.create(:stolen_record, current: true, tsved_at: Time.now)
      stolen2 = FactoryGirl.create(:stolen_record, current: true, tsved_at: nil)

      expect(StolenRecord.tsv_today.pluck(:id)).to eq([stolen1.id, stolen2.id])
    end
  end

  it "only allows one current stolen record per bike"

  describe :address do 
    it "creates an address" do 
      c = Country.create(name: "Neverland", iso: "XXX")
      s = State.create(country_id: c.id, name: "BullShit", abbreviation: "XXX")
      stolen_record = FactoryGirl.create(:stolen_record, street: "2200 N Milwaukee Ave", city: "Chicago", state_id: s.id, zipcode: "60647", country_id: c.id)
      stolen_record.address.should eq("2200 N Milwaukee Ave, Chicago, XXX, 60647, Neverland")
    end
  end

  describe "scopes" do 
    it "only includes current records" do 
      StolenRecord.scoped.to_sql.should == StolenRecord.where(current: true).to_sql
    end
  
    it "only includes non-current in recovered" do 
      StolenRecord.recovered.to_sql.should == StolenRecord.where(current: false).order("date_recovered desc").to_sql
    end

    it "only includes sharable unapproved in recovery_waiting_share_approval" do 
      StolenRecord.recovery_unposted.to_sql.should == StolenRecord.where(current: false, recovery_posted: false).to_sql
    end
  end

  describe :tsv_row do 
    it "returns the tsv row" do 
      stolen_record = FactoryGirl.create(:stolen_record)
      stolen_record.bike.update_attribute :description, "I like tabs because i'm an \\tass\T right\N"
      row = stolen_record.tsv_row
      row.split("\t").count.should eq(10)
      row.split("\n").count.should eq(1)
    end

    it "doesn't show the serial for recovered bikes" do 
      stolen_record = FactoryGirl.create(:stolen_record)
      stolen_record.bike.update_attributes(serial_number: "SERIAL_SERIAL", recovered: true)
      row = stolen_record.tsv_row
      row.should_not match(/serial_serial/i)
    end
  end

  describe :set_phone do 
    it "it should set_phone" do 
      stolen_record = FactoryGirl.create(:stolen_record)
      stolen_record.phone = '000/000/0000'
      stolen_record.secondary_phone = '000/000/0000'
      stolen_record.set_phone
      stolen_record.phone.should eq('0000000000')
      stolen_record.secondary_phone.should eq('0000000000')
    end
    it "has before_save_callback_method defined as a before_save callback" do
      StolenRecord._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_phone).should == true
    end
  end

  describe :titleize_city do 
    it "it should titleize_city" do 
      stolen_record = FactoryGirl.create(:stolen_record)
      stolen_record.city = 'INDIANAPOLIS, IN USA'
      stolen_record.titleize_city
      stolen_record.city.should eq('Indianapolis')
    end

    it "it shouldn't remove other things" do 
      stolen_record = FactoryGirl.create(:stolen_record)
      stolen_record.city = 'Georgian la'
      stolen_record.titleize_city
      stolen_record.city.should eq('Georgian La')
    end
    it "has before_save_callback_method defined as a before_save callback" do
      StolenRecord._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:titleize_city).should == true
    end
  end

  describe :fix_date do 
    it "it should set the year to something not stupid" do 
      stolen_record = StolenRecord.new
      stupid_year = Date.strptime("07-22-0014", "%m-%d-%Y")
      stolen_record.date_stolen = stupid_year
      stolen_record.fix_date
      stolen_record.date_stolen.year.should eq(2014)
    end
    it "it should set the year to not last century" do
      stolen_record = StolenRecord.new
      wrong_century = Date.strptime("07-22-1913", "%m-%d-%Y")
      stolen_record.date_stolen = wrong_century
      stolen_record.fix_date
      stolen_record.date_stolen.year.should eq(2013)
    end
    it "it should set the year to the past year if the date hasn't happened yet" do 
      stolen_record = FactoryGirl.create(:stolen_record)
      next_year = (Time.now + 2.months)
      stolen_record.date_stolen = next_year
      stolen_record.fix_date
      stolen_record.date_stolen.year.should eq(Time.now.year - 1)
    end

    it "has before_save_callback_method defined as a before_save callback" do
      StolenRecord._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:fix_date).should == true
    end
  end

  describe :update_tsved_at do 
    it "does not reset on save" do 
      t = Time.now - 1.minute
      stolen_record = FactoryGirl.create(:stolen_record, tsved_at: t)
      stolen_record.update_attributes(theft_description: 'Something new description wise')
      stolen_record.reload
      expect(stolen_record.tsved_at.to_i).to eq(t.to_i)
    end
    it "resets from an update to police report" do 
      t = Time.now - 1.minute
      stolen_record = FactoryGirl.create(:stolen_record, tsved_at: t)
      stolen_record.update_attributes(police_report_number: '89dasf89dasf')
      stolen_record.reload
      expect(stolen_record.tsved_at).to be_nil
    end
    it "resets from an update to police report department" do 
      t = Time.now - 1.minute
      stolen_record = FactoryGirl.create(:stolen_record, tsved_at: t)
      stolen_record.update_attributes(police_report_department: 'CPD')
      stolen_record.reload
      expect(stolen_record.tsved_at).to be_nil
    end

  end

end
