require 'spec_helper'

describe EmailAdminContactStolenWorker do
  it { is_expected.to be_processed_in :notify }

  describe 'perform' do
    it 'sends an email' do
      customer_contact = FactoryGirl.create(:customer_contact)
      ActionMailer::Base.deliveries = []
      EmailAdminContactStolenWorker.new.perform(customer_contact.id)
      expect(ActionMailer::Base.deliveries).not_to be_empty
    end
  end
end
