require 'spec_helper'

describe EmailAdminContactStolenWorker do
  it { is_expected.to be_processed_in :notify }

  describe 'perform' do
    it 'sends an email' do
      stolen_record = FactoryGirl.create(:stolen_record)
      FactoryGirl.create(:ownership, bike: stolen_record.bike)
      customer_contact = FactoryGirl.create(:customer_contact, bike: stolen_record.bike)
      ActionMailer::Base.deliveries = []
      EmailAdminContactStolenWorker.new.perform(customer_contact.id)
      expect(ActionMailer::Base.deliveries).not_to be_empty
    end
  end
end
