require "rails_helper"

RSpec.describe Backfills::OrganizationPaidMoneyJob, type: :job do
  describe "perform" do
    let!(:paid) { FactoryBot.create(:invoice_with_payment).organization }
    let!(:free) { FactoryBot.create(:organization, :with_invoice) }
    let!(:expired) do
      FactoryBot.create(:invoice_with_payment, start_at: Time.current - 2.years,
        end_at: Time.current - 1.year).organization
    end
    # The migration defaulted every organization to false, which is the state the job runs against
    before { Organization.update_all(paid_money: false) }

    it "sets paid_money for the organizations with a current invoice they paid money for" do
      Sidekiq::Testing.inline! { described_class.perform_async }

      expect(paid.reload.paid_money).to be_truthy
      expect(free.reload.paid_money).to be_falsey
      expect(expired.reload.paid_money).to be_falsey
    end
  end
end
