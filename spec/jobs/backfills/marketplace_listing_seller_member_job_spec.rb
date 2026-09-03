require "rails_helper"

RSpec.describe Backfills::MarketplaceListingSellerMemberJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:member) { FactoryBot.create(:user_confirmed, :with_address_record) }
    let!(:membership) { FactoryBot.create(:membership, user: member) }

    it "backfills current listings from the seller's current membership" do
      member_listing = FactoryBot.create(:marketplace_listing, :for_sale, seller: member, address_record: member.address_record)
      non_member_listing = FactoryBot.create(:marketplace_listing, :for_sale)
      # Simulate the pre-backfill stale state (the migration defaulted seller_member to false)
      member_listing.update_column(:seller_member, false)
      non_member_listing.update_column(:seller_member, true)
      bike_updated_at = member_listing.item.reload.updated_at

      instance.perform

      expect(member_listing.reload.seller_member).to be true
      expect(non_member_listing.reload.seller_member).to be false
      # the member listing's bike cache key is busted so the badge re-renders
      expect(member_listing.item.reload.updated_at).to be > bike_updated_at
    end

    it "reconstructs a sold listing from the membership active when it ended" do
      membership.update!(start_at: Time.current - 2.years, end_at: Time.current - 6.months)
      expect(member.reload.member?).to be false
      sold = FactoryBot.create(:marketplace_listing, :sold, seller: member,
        published_at: Time.current - 18.months, end_at: Time.current - 1.year)
      expect(sold.reload.seller_member).to be false # not set, since created non-current

      instance.perform
      expect(sold.reload.seller_member).to be true # was a member when it ended, a year ago
    end
  end
end
