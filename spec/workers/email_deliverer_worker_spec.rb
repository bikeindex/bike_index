require 'spec_helper'

describe EmailAdminContactStolenWorker do
  it { is_expected.to be_processed_in :notify }

  describe 'customer_mailer methods' do
    before each do
      ActionMailer::Base.deliveries = []
    end
    context 'ownership_invitation_email' do
      let(:mailer_method) { 'ownership_invitation_email' }
      it 'sends an email' do
        customer_contact = FactoryGirl.create(:customer_contact)
        EmailDelivererWorker.new.perform(mailer_method, ids: { customer_contact: customer_contact.id })
        expect(ActionMailer::Base.deliveries).not_to be_empty
      end
    end
  end
end

