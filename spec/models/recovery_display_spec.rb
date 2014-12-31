require 'spec_helper'

describe RecoveryDisplay do
  describe :validations do 
    it { should validate_presence_of :quote }
    it { should belong_to :stolen_record }
    # Before validation sets it, so test fails
    # it { should validate_presence_of :recovered_at } 
  end

  describe :set_time do 
    it "sets time from input" do
      recovery_display = RecoveryDisplay.new(date_input: '04-27-1999')
      recovery_display.set_time
      recovery_display.date_recovered.should eq(DateTime.strptime("04-27-1999 06", "%m-%d-%Y %H"))
    end
    it "sets time if no time" do 
      recovery_display = RecoveryDisplay.new
      recovery_display.set_time
      recovery_display.date_recovered.should be > Time.now - 5.seconds
    end
    it "has before_validation_callback_method defined" do
      RecoveryDisplay._validation_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_time).should == true
    end
  end

  describe :from_stolen_record do 
    it "doesn't break if stolen record isn't present" do 
      recovery_display = RecoveryDisplay.new
      recovery_display.from_stolen_record(69)
      recovery_display.errors.should_not be_present
    end
    it "sets attrs from stolen record" do 
      t = Time.now
      stolen_record = FactoryGirl.create(:stolen_record, date_recovered: t, recovered_description: 'stuff', current: false)
      recovery_display = RecoveryDisplay.new
      recovery_display.from_stolen_record(stolen_record.id)
      recovery_display.quote.should eq('stuff')
      recovery_display.date_recovered.should be > Time.now - 5.seconds
      recovery_display.stolen_record_id.should eq(stolen_record.id)
    end
    it "sets name from stolen record" do 
      user = FactoryGirl.create(:user, name: 'somebody special')
      ownership = FactoryGirl.create(:ownership, creator: user, user: user)
      stolen_record = FactoryGirl.create(:stolen_record, bike: ownership.bike)
      recovery_display = RecoveryDisplay.new
      recovery_display.from_stolen_record(stolen_record.id)
      recovery_display.quote_by.should eq('somebody special')
    end
  end

end
