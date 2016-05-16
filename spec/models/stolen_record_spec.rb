require 'spec_helper'

describe StolenRecord do
  describe 'validations' do
    it { is_expected.to validate_presence_of :bike }
    it { is_expected.to validate_presence_of :date_stolen }
    it { is_expected.to belong_to :bike }
    it { is_expected.to have_one :recovery_display }
    it { is_expected.to belong_to :country }
    it { is_expected.to belong_to :state }
    it { is_expected.to belong_to :creation_organization }
  end

  it 'marks current true by default' do
    stolenRecord = StolenRecord.new
    expect(stolenRecord.current).to be_truthy
  end

  describe 'scopes' do
    it 'default scopes to current' do
      expect(StolenRecord.scoped.to_sql).to eq(StolenRecord.where(current: true).to_sql)
    end
    it 'scopes approveds' do
      expect(StolenRecord.approveds.to_sql).to eq(StolenRecord.where(current: true).where(approved: true).to_sql)
    end
    it 'scopes approveds_with_reports' do
      expect(StolenRecord.approveds_with_reports.to_sql).to eq(StolenRecord.where(current: true).where(approved: true)
        .where('police_report_number IS NOT NULL').where('police_report_department IS NOT NULL').to_sql)
    end

    it 'scopes not_tsved' do
      expect(StolenRecord.not_tsved.to_sql).to eq(StolenRecord.where(current: true).where('tsved_at IS NULL').to_sql)
    end
    it 'scopes recovered' do
      expect(StolenRecord.recovered.to_sql).to eq(StolenRecord.unscoped.where(current: false).order('date_recovered desc').to_sql)
    end
    it 'scopes displayable' do
      expect(StolenRecord.displayable.to_sql).to eq(StolenRecord.unscoped.where(current: false, can_share_recovery: true).order('date_recovered desc').to_sql)
    end
    it 'scopes recovery_unposted' do
      expect(StolenRecord.recovery_unposted.to_sql).to eq(StolenRecord.unscoped.where(current: false, recovery_posted: false).to_sql)
    end
    it 'scopes tsv_today' do
      stolen1 = FactoryGirl.create(:stolenRecord, current: true, tsved_at: Time.now)
      stolen2 = FactoryGirl.create(:stolenRecord, current: true, tsved_at: nil)

      expect(StolenRecord.tsv_today.pluck(:id)).to eq([stolen1.id, stolen2.id])
    end
  end

  it 'only allows one current stolen record per bike'

  describe 'address' do
    it 'creates an address' do
      c = Country.create(name: 'Neverland', iso: 'XXX')
      s = State.create(country_id: c.id, name: 'BullShit', abbreviation: 'XXX')
      stolenRecord = FactoryGirl.create(:stolenRecord, street: '2200 N Milwaukee Ave', city: 'Chicago', state_id: s.id, zipcode: '60647', country_id: c.id)
      expect(stolenRecord.address).to eq('2200 N Milwaukee Ave, Chicago, XXX, 60647, Neverland')
    end
  end

  describe 'scopes' do
    it 'only includes current records' do
      expect(StolenRecord.scoped.to_sql).to eq(StolenRecord.where(current: true).to_sql)
    end

    it 'only includes non-current in recovered' do
      expect(StolenRecord.recovered.to_sql).to eq(StolenRecord.where(current: false).order('date_recovered desc').to_sql)
    end

    it 'only includes sharable unapproved in recovery_waiting_share_approval' do
      expect(StolenRecord.recovery_unposted.to_sql).to eq(StolenRecord.where(current: false, recovery_posted: false).to_sql)
    end
  end

  describe 'tsv_row' do
    it 'returns the tsv row' do
      stolenRecord = FactoryGirl.create(:stolenRecord)
      stolenRecord.bike.update_attribute :description, "I like tabs because i'm an \\tass\T right\N"
      row = stolenRecord.tsv_row
      expect(row.split("\t").count).to eq(10)
      expect(row.split("\n").count).to eq(1)
    end

    it "doesn't show the serial for recovered bikes" do
      stolenRecord = FactoryGirl.create(:stolenRecord)
      stolenRecord.bike.update_attributes(serial_number: 'SERIAL_SERIAL', recovered: true)
      row = stolenRecord.tsv_row
      expect(row).not_to match(/serial_serial/i)
    end
  end

  describe 'set_phone' do
    it 'it should set_phone' do
      stolenRecord = FactoryGirl.create(:stolenRecord)
      stolenRecord.phone = '000/000/0000'
      stolenRecord.secondary_phone = '000/000/0000'
      stolenRecord.set_phone
      expect(stolenRecord.phone).to eq('0000000000')
      expect(stolenRecord.secondary_phone).to eq('0000000000')
    end
    it 'has before_save_callback_method defined as a before_save callback' do
      expect(StolenRecord._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_phone)).to eq(true)
    end
  end

  describe 'titleize_city' do
    it 'it should titleize_city' do
      stolenRecord = FactoryGirl.create(:stolenRecord)
      stolenRecord.city = 'INDIANAPOLIS, IN USA'
      stolenRecord.titleize_city
      expect(stolenRecord.city).to eq('Indianapolis')
    end

    it "it shouldn't remove other things" do
      stolenRecord = FactoryGirl.create(:stolenRecord)
      stolenRecord.city = 'Georgian la'
      stolenRecord.titleize_city
      expect(stolenRecord.city).to eq('Georgian La')
    end
    it 'has before_save_callback_method defined as a before_save callback' do
      expect(StolenRecord._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:titleize_city)).to eq(true)
    end
  end

  describe 'fix_date' do
    it 'it should set the year to something not stupid' do
      stolenRecord = StolenRecord.new
      stupid_year = Date.strptime('07-22-0014', '%m-%d-%Y')
      stolenRecord.date_stolen = stupid_year
      stolenRecord.fix_date
      expect(stolenRecord.date_stolen.year).to eq(2014)
    end
    it 'it should set the year to not last century' do
      stolenRecord = StolenRecord.new
      wrong_century = Date.strptime('07-22-1913', '%m-%d-%Y')
      stolenRecord.date_stolen = wrong_century
      stolenRecord.fix_date
      expect(stolenRecord.date_stolen.year).to eq(2013)
    end
    it "it should set the year to the past year if the date hasn't happened yet" do
      stolenRecord = FactoryGirl.create(:stolenRecord)
      next_year = (Time.now + 2.months)
      stolenRecord.date_stolen = next_year
      stolenRecord.fix_date
      expect(stolenRecord.date_stolen.year).to eq(Time.now.year - 1)
    end

    it 'has before_save_callback_method defined as a before_save callback' do
      expect(StolenRecord._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:fix_date)).to eq(true)
    end
  end

  describe 'update_tsved_at' do
    it 'does not reset on save' do
      t = Time.now - 1.minute
      stolenRecord = FactoryGirl.create(:stolenRecord, tsved_at: t)
      stolenRecord.update_attributes(theft_description: 'Something new description wise')
      stolenRecord.reload
      expect(stolenRecord.tsved_at.to_i).to eq(t.to_i)
    end
    it 'resets from an update to police report' do
      t = Time.now - 1.minute
      stolenRecord = FactoryGirl.create(:stolenRecord, tsved_at: t)
      stolenRecord.update_attributes(police_report_number: '89dasf89dasf')
      stolenRecord.reload
      expect(stolenRecord.tsved_at).to be_nil
    end
    it 'resets from an update to police report department' do
      t = Time.now - 1.minute
      stolenRecord = FactoryGirl.create(:stolenRecord, tsved_at: t)
      stolenRecord.update_attributes(police_report_department: 'CPD')
      stolenRecord.reload
      expect(stolenRecord.tsved_at).to be_nil
    end
  end
end
