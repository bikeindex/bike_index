require "rails_helper"

RSpec.describe ItemSale, type: :model do
  it_behaves_like "amountable"

  describe "factory" do
    let(:item_sale) { FactoryBot.create(:item_sale) }
    it "is valid" do
      expect(item_sale).to be_valid
      expect(item_sale.ownership_id).to be_present
    end
  end
end
