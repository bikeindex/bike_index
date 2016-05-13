require 'spec_helper'

describe RecoveryDisplay do
  describe 'validations' do
    it { is_expected.to validate_presence_of :quote }
    it { is_expected.to belong_to :stolenRecord }
    # Before validation sets it, so test fails
    # it { should validate_presence_of :recovered_at }
  end

  describe 'set_time' do
    it 'sets time from input' do
      recovery_display = RecoveryDisplay.new(date_input: '04-27-1999')
      recovery_display.set_time
      expect(recovery_display.date_recovered).to eq(DateTime.strptime('04-27-1999 06', '%m-%d-%Y %H'))
    end
    it 'sets time if no time' do
      recovery_display = RecoveryDisplay.new
      recovery_display.set_time
      expect(recovery_display.date_recovered).to be > Time.now - 5.seconds
    end
    it 'has before_validation_callback_method defined' do
      expect(RecoveryDisplay._validation_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_time)).to eq(true)
    end
  end

  describe 'from_stolenRecord' do
    it "doesn't break if stolen record isn't present" do
      recovery_display = RecoveryDisplay.new
      recovery_display.from_stolenRecord(69)
      expect(recovery_display.errors).not_to be_present
    end
    it 'sets attrs from stolen record' do
      t = Time.now
      stolenRecord = FactoryGirl.create(:stolenRecord, date_recovered: t, recovered_description: 'stuff', current: false)
      recovery_display = RecoveryDisplay.new
      recovery_display.from_stolenRecord(stolenRecord.id)
      expect(recovery_display.quote).to eq('stuff')
      expect(recovery_display.date_recovered).to be > Time.now - 5.seconds
      expect(recovery_display.stolenRecord_id).to eq(stolenRecord.id)
    end
    it 'sets name from stolen record' do
      user = FactoryGirl.create(:user, name: 'somebody special')
      ownership = FactoryGirl.create(:ownership, creator: user, user: user)
      stolenRecord = FactoryGirl.create(:stolenRecord, bike: ownership.bike)
      recovery_display = RecoveryDisplay.new
      recovery_display.from_stolenRecord(stolenRecord.id)
      expect(recovery_display.quote_by).to eq('somebody special')
    end
  end
end
