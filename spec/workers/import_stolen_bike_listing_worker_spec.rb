require "rails_helper"

RSpec.describe ImportStolenBikeListingWorker, type: :lib do
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
        frame_model: "whatever",
        price: "203.33",
        listing: "something something All City, etc",
        photo_urls: []
      }
    end
    it "creates a StolenBikeListing" do
      stolen_bike_listing = instance.perform(row.as_json)
      expect(stolen_bike_listing.primary_frame_color_id).to eq Color.black.id
      expect(stolen_bike_listing.manufacturer_id).to eq manufacturer.id
      expect(stolen_bike_listing.amount).to eq 203.33
      expect(stolen_bike_listing.currency).to eq "MXN"
      expect(stolen_bike_listing.amount_formatted).to eq "$203.33"
      expect(stolen_bike_listing.frame_model).to eq "whatever"
      expect(stolen_bike_listing.listing_text).to eq row[:listing]
      expect(stolen_bike_listing.listed_at).to be_within(1.day).of Time.parse("2020-11-3")
      expect(stolen_bike_listing.photo_urls).to eq([])
    end
  end

  describe "color_attrs" do
    before do
      Color.black # So we get the correct black attributes
      (Color::ALL_NAMES - ["Black"]).each { |c| FactoryBot.create(:color, name: c) }
    end

    it "finds manufacturer if possible" do
      pp Color.black.id
      expect(instance.color_attrs("Black")).to eq({primary_frame_color_id: Color.black.id, secondary_frame_color_id: nil, tertiary_frame_color_id: nil})
      expect(instance.color_attrs("Blk/Purpl")).to eq({primary_frame_color_id: Color.black.id, secondary_frame_color_id: Color.friendly_id_find("purple"), tertiary_frame_color_id: nil})
    end
  end

  describe "manufacturer_attrs" do
    let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Specialized (bike company)") }
    it "finds manufacturer if possible" do
      expect(instance.manufacturer_attrs("Specialized")).to eq({manufacturer_id: manufacturer.id})
      expect(instance.manufacturer_attrs("Not Specialized")).to eq({manufacturer_id: Manufacturer.other.id, manufacturer_other: "Not Specialized"})
    end
  end
end
