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

  describe "build_and_authorize" do
    let(:item) { FactoryBot.create(:bike, :with_ownership_claimed, :with_primary_activity, cycle_type: :unicycle) }
    let(:ownership) { item.current_ownership }

    context "marketplace_message sale" do
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item:) }
      let(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:) }
      let(:result) { Sale.build_and_authorize(user:, marketplace_message_id: marketplace_message.id) }
      let(:target_attrs) do
        {
          item_id: item.id,
          ownership_id: ownership.id,
          seller_id: ownership.user_id,
          sold_via: "bike_index_marketplace",
          new_owner_email: marketplace_message.sender.email
        }
      end
      let(:user) { ownership.user }

      it "returns sale and nil" do
        expect(result.length).to eq 2
        expect(result.first).to match_hash_indifferently target_attrs
        expect(result.first.valid?).to be_truthy
        expect(result.last).to be_nil
      end

      context "not user's" do
        let(:user) { marketplace_message.sender }
        it "returns invalid sale and error_message" do
          expect(result.length).to eq 2
          expect(result.first.valid?).to be_falsey
          expect(result.last).to eq "You don't have permission to sell that unicycle"
        end
      end
    end

    context "unknown item" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      let(:result) { Sale.build_and_authorize(user:, marketplace_message_id: 9993333) }
      it "returns invalid sale and error_message" do
        expect(result.length).to eq 2
        expect(result.first.valid?).to be_falsey
        expect(result.last).to eq "Unable to find that bike"
      end
    end
  end

  describe "set_calculated_attributes" do
    let(:item) { FactoryBot.create(:bike, :with_ownership_claimed, :with_primary_activity) }
    let(:ownership) { item.current_ownership }

    context "marketplace_message_id" do
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item:) }
      let(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:) }
      let(:sale) { Sale.new(marketplace_message_id: marketplace_message.id) }
      let(:target_attrs) do
        {
          item_id: item.id,
          ownership_id: ownership.id,
          seller_id: ownership.user_id,
          sold_via: "bike_index_marketplace",
          new_owner_email: marketplace_message.sender.email,
          sold_at: Time.current
        }
      end

      it "assigns the correct ownership" do
        expect(sale).to be_valid
        sale.save!
        expect(sale).to match_hash_indifferently target_attrs
      end
    end
  end
end
