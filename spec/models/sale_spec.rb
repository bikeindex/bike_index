require "rails_helper"

RSpec.describe Sale, type: :model do
  it_behaves_like "amountable"
  it_behaves_like "currencyable"

  describe "factory" do
    let(:sale) { FactoryBot.create(:sale) }
    it "is valid" do
      expect(sale).to be_valid
      expect(sale.ownership_id).to be_present
      expect(CallbackJob::AfterSaleCreateJob.jobs.count).to eq 1
    end
  end
end
