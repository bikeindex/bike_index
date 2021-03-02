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
      stolen_bike_listing = instance.perform("constru", 12, row.as_json)
      expect(stolen_bike_listing.group).to eq "constru"
      expect(stolen_bike_listing.line).to eq 12
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
    before { Color.black }
    let(:black_target) { {primary_frame_color_id: Color.black.id, secondary_frame_color_id: nil, tertiary_frame_color_id: nil} }

    it "finds black" do
      expect(instance.color_attrs("Black")).to eq black_target
      expect(instance.color_attrs("BLK")).to eq black_target
      expect(instance.color_attrs("BLk/")).to eq black_target
    end
    context "all colors" do
      it "finds color if possible" do
        # Create all the other colors
        (Color::ALL_NAMES - ["Black"]).each { |c| FactoryBot.create(:color, name: c) }
        # Ensure with all the other colors, we still get same result
        expect(instance.color_attrs("Blk")).to eq black_target
        # And test with multiple colors
        purple_target = black_target.merge(secondary_frame_color_id: Color.friendly_id_find("purple"))
        expect(instance.color_attrs("Black/Purple")).to eq purple_target
        expect(instance.color_attrs("Blk/Purpl")).to eq purple_target
        # And test with 3 colors
        expect(Color.friendly_id_find("silver")).to be_present # Sanity check
        expect(instance.color_attrs("Blk/Purpl/silver")).to eq purple_target.merge(tertiary_frame_color_id: Color.friendly_id_find("silver"))
      end
    end
  end

  describe "manufacturer_attrs" do
    let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Specialized (bike company)") }
    it "finds manufacturer if possible" do
      expect(instance.manufacturer_attrs("Specialized")).to eq({manufacturer_id: manufacturer.id})
      expect(instance.manufacturer_attrs("Not Specialized")).to eq({manufacturer_id: Manufacturer.other.id, manufacturer_other: "Not Specialized"})
    end
  end

  describe "find_bike_id" do
    let(:owner_found) { "https://bikeindex.org/bikes/988404 confirmed match" }
    it "returns bike id" do
      expect(instance.find_bike_id(owner_found)).to eq "988404"
    end
    context "none found" do
      let(:owner_found) { "none found" }
      it "returns nil" do
        expect(instance.find_bike_id(owner_found)).to eq nil
      end
    end
  end
end
