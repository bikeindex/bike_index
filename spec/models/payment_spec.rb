require 'spec_helper'

describe Payment do
  describe :validations do
    it { should belong_to :user }
    it { should validate_presence_of :email }
  end


  describe :create do
    it "enqueues an email job" do
      expect {
        FactoryGirl.create(:payment)
      }.to change(EmailInvoiceWorker.jobs, :size).by(1)
    end
  end

end
