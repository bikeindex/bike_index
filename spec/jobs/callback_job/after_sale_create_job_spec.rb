require "rails_helper"

RSpec.describe CallbackJob::AfterSaleCreateJob, type: :job do
  let(:instance) { described_class.new }
  before { Sidekiq::Job.clear_all }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "high_priority"
  end

  it "doesn't break if unable to find sale" do
    instance.perform(96)
  end

  describe "with marketplace_listing" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:bike) { FactoryBot.create(:bike, :with_primary_activity, :with_ownership_claimed, user:) }
    let(:ownership) { bike.current_ownership }
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, item: bike) }
    let(:marketplace_message) { FactoryBot.create(:marketplace_message, marketplace_listing:) }
    let(:buyer) { marketplace_message.sender }
    let(:sale) { Sale.create(marketplace_message:, ownership:) }
    let(:new_ownership_attrs) do
      {
        creator_id: user.id,
        origin: "transferred_ownership",
        skip_email: false,
        registration_info: {},
        status: "status_with_owner",
        sale_id: sale.id,
        current: true,
        previous_ownership_id: ownership.id,
        claimed: false
      }
    end

    it "updates the listing order" do
      expect(sale).to be_valid
      expect(sale.reload.new_owner_email).to eq buyer.email
      expect(sale.item_id).to eq bike.id
      expect(sale.new_ownership).to be_blank
      expect(sale.sold_via).to eq "bike_index_marketplace"

      expect(ownership.sale_sold_in&.id).to eq sale.id

      expect(marketplace_listing.reload.sale_id).to be_nil
      expect(marketplace_listing.status).to eq "for_sale"
      expect(marketplace_listing.buyer_id).to be_nil

      expect(bike.reload.current_ownership.id).to eq ownership.id
      expect(bike.is_for_sale).to be_truthy
      expect(bike.ownerships.count).to eq 1

      expect do
        instance.perform(sale.id)
        instance.perform(sale.id)
      end.to change(Ownership, :count).by 1

      expect(sale.reload.new_owner_email).to eq buyer.email
      expect(sale.amount_cents).to be_nil
      new_ownership = sale.new_ownership
      expect(new_ownership).to match_hash_indifferently new_ownership_attrs

      expect(bike.reload.is_for_sale).to be_falsey
      expect(bike.current_ownership.id).to eq new_ownership.id

      expect(ownership.reload.current).to be_falsey
      expect(ownership.sale_id).to be_nil
      expect(ownership.sale_sold_in&.id).to eq sale.id

      expect(marketplace_listing.reload.sale_id).to eq sale.id
      expect(marketplace_listing.status).to eq "sold"
      expect(marketplace_listing.buyer_id).to eq buyer.id
      expect(marketplace_listing.end_at).to be_within(5).of Time.current
    end
  end
end
