require 'spec_helper'

describe Payment do
  describe 'validations' do
    it { is_expected.to belong_to :user }
    it { is_expected.to validate_presence_of :email }
  end

  describe 'create' do
    it 'enqueues an email job' do
      expect do
        FactoryGirl.create(:payment)
      end.to change(EmailInvoiceWorker.jobs, :size).by(1)
    end
  end
end
