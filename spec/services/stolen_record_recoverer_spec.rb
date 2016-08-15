require 'spec_helper'

describe StolenRecordRecoverer do
  describe 'update' do
    it 'updates recovered bike' do
      bike = FactoryGirl.create(:stolen_bike)
      stolen_record = bike.current_stolen_record
      expect(bike.stolen).to be_truthy
      recovery_request = {
        request_type: 'bike_recovery',
        user_id: 69,
        request_bike_id: bike.id,
        request_reason: 'Some reason',
        index_helped_recovery: 'true',
        can_share_recovery: 'false'
      }
      StolenRecordRecoverer.new.update(stolen_record.id, recovery_request.as_json)
      bike.reload
      stolen_record.reload
      expect(bike.stolen).to be_falsey
      expect(bike.current_stolen_record).not_to be_present
      expect(stolen_record.reload.date_recovered).to be_within(1.second).of Time.now
      expect(stolen_record.index_helped_recovery).to be_truthy
      expect(stolen_record.can_share_recovery).to be_falsey
    end
  end
end
