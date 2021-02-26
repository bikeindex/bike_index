require "rails_helper"

RSpec.describe TheftRingListing, type: :model do
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color) }

  describe "amount" do
    let(:theft_ring_listing) { FactoryBot.build(:theft_ring_listing, amount_cents: 12_000) }
    it "is in pesos" do
      expect(theft_ring_listing.amount_formatted).to eq "₱12,000"
    end
  end

  describe "searchable" do
    let(:interpreted_params) { TheftRingListing.searchable_interpreted_params(query_params) }
    context "color_ids of primary, secondary and tertiary" do
      let(:color_2) { FactoryBot.create(:color) }
      let(:theft_ring_listing1) { FactoryBot.create(:theft_ring_listing, primary_frame_color: color, listed_at: Time.current - 3.months) }
      let(:theft_ring_listing2) { FactoryBot.create(:theft_ring_listing, secondary_frame_color: color, tertiary_frame_color: color_2, listed_at: Time.current - 2.weeks) }
      let(:theft_ring_listing3) { FactoryBot.create(:theft_ring_listing, tertiary_frame_color: color, manufacturer: manufacturer) }
      let(:all_color_ids) do
        [
          theft_ring_listing1.primary_frame_color_id,
          theft_ring_listing2.primary_frame_color_id,
          theft_ring_listing3.primary_frame_color_id,
          theft_ring_listing1.secondary_frame_color_id,
          theft_ring_listing2.secondary_frame_color_id,
          theft_ring_listing3.secondary_frame_color_id,
          theft_ring_listing1.tertiary_frame_color_id,
          theft_ring_listing2.tertiary_frame_color_id,
          theft_ring_listing3.tertiary_frame_color_id
        ]
      end
      before do
        expect(all_color_ids.count(color.id)).to eq 3 # Each bike has color only once
      end
      context "single color" do
        let(:query_params) { {colors: [color.id], stolenness: "all"} }
        it "matches bikes with the given color" do
          expect(theft_ring_listing1.listing_order < theft_ring_listing2.listing_order).to be_truthy
          expect(theft_ring_listing2.listing_order < theft_ring_listing3.listing_order).to be_truthy
          expect(TheftRingListing.search(interpreted_params).pluck(:id)).to eq([theft_ring_listing3.id, theft_ring_listing2.id, theft_ring_listing1.id])
        end
      end
      context "second color" do
        let(:query_params) { {colors: [color.id, color_2.id], stolenness: "all"} }
        it "matches just the bike with both colors" do
          expect(TheftRingListing.search(interpreted_params).pluck(:id)).to eq([theft_ring_listing2.id])
        end
      end
      context "and manufacturer_id" do
        let(:query_params) { {colors: [color.id], manufacturer: manufacturer.id, stolenness: "all"} }
        it "matches just the bike with the matching manufacturer" do
          expect(TheftRingListing.search(interpreted_params).pluck(:id)).to eq([theft_ring_listing3.id])
        end
      end
    end
  end
end
