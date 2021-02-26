require "rails_helper"

RSpec.describe ImportTheftRingListingWorker, type: :lib do
  let(:subject) { described_class }
  let(:instance) { subject.new }

  describe "perform row" do
    let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "All City") }
    let!(:color) { Color.black }
    let(:row) do
      {
        color: "Black",
        manufacturer: "All City",
        listed_at: "2020-11-3",
        amount_cents: 20333,
        frame_model: "whatever",
        listing: "something something All City, etc",
        photo_urls: []
      }
    end
    it "creates a TheftRingListing" do
      theft_ring_listing = instance.perform(row.as_json)
      expect(theft_ring_listing.color_id).to eq Color.black
      expect(theft_ring_listing.manufacturer_id).to eq manufacturer.id
      expect(theft_ring_listing.amount).to eq 203.33
      expect(theft_ring_listing.frame_model).to eq "whatever"
      expect(theft_ring_listing.listing).to eq row[:listing]
      expect(theft_ring_listing.listed_at).to be_within(1.day).of Time.parse("2020-11-3")
      expect(theft_ring_listing.photo_urls).to eq([])
    end
  end

  describe "color_attrs" do
    include_context :create_all_colors
    it "finds manufacturer if possible" do
      expect(subject.color_attrs("Black")).to eq({primary_primary_frame_color_id: Color.black, secondary_primary_frame_color_id: nil, tertiary_primary_frame_color_id: nil})
      expect(subject.color_attrs("Blk/Purpl")).to eq({primary_primary_frame_color_id: Color.black.id, secondary_primary_frame_color_id: Color.friendly_find("purple").id, tertiary_primary_frame_color_id: nil})
    end
  end

  describe "manufacturer_attrs" do
    let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Specialized (bike company)") }
    it "finds manufacturer if possible" do
      expect(subject.manufacturer_attrs("Specialized")).to eq({manufacturer_id: manufacturer.id})
      expect(subject.manufacturer_attrs("Not Specialized")).to eq({manufacturer_id: Manufacturer.other.id, manufacturer_other: "Not Specialized"})
    end
  end
end
