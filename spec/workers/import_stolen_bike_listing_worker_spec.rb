require "rails_helper"

RSpec.describe ImportStolenBikeListingWorker, type: :lib do
  let(:subject) { described_class }
  let(:instance) { subject.new }

  def header_values(row)
    ImportStolenBikeListingWorker::HEADERS.map { |h| row[h] }.join(",")
  end

  describe "perform row" do
    let!(:exchange_rate) { FactoryBot.create(:exchange_rate, from: "MXN", to: "USD", rate: 0.047) }
    let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "All City") }
    let!(:color) { Color.black }
    let(:row) do
      {
        line: "12",
        listed_at: "2020-12-14",
        folder: "Dec 14 2020_003",
        bike: " ",
        repost: "no",
        price: "203.33",
        manufacturer: "All City",
        model: "whatever",
        size: "56",
        color: "Black",
        bike_index_bike: "",
        notes: "something else",
        listing_text: "something something All City 26&#34;"
      }
    end
    it "creates a StolenBikeListing" do
      expect(StolenBikeListing.count).to eq 0
      stolen_bike_listing = instance.perform("constru", 12, header_values(row))
      expect(StolenBikeListing.count).to eq 1
      expect(stolen_bike_listing.group).to eq "constru"
      expect(stolen_bike_listing.line).to eq 12
      expect(stolen_bike_listing.primary_frame_color_id).to eq Color.black.id
      expect(stolen_bike_listing.manufacturer_id).to eq manufacturer.id
      expect(stolen_bike_listing.amount).to eq 203.33
      expect(stolen_bike_listing.currency).to eq "MXN"
      expect(stolen_bike_listing.amount_formatted).to eq "$203.33"
      expect(stolen_bike_listing.frame_model).to eq "whatever"
      expect(stolen_bike_listing.listing_text).to eq "something something All City 26\""
      expect(stolen_bike_listing.listed_at).to be_within(1.day).of Time.parse("2020-12-14")
      expect(stolen_bike_listing.photo_urls).to eq([])
      expect(stolen_bike_listing.data.dig("notes")).to eq("something else")
      expect(stolen_bike_listing.data.dig("photo_folder")).to eq("Dec 14 2020_003")
      # And test frame_size
      expect(stolen_bike_listing.frame_size_number).to eq 56
      expect(stolen_bike_listing.frame_size_unit).to eq "cm"
      expect(stolen_bike_listing.frame_size).to eq "56cm"
      expect {
        instance.perform("constru", 12, header_values(row))
      }.to_not change(StolenBikeListing, :count)
    end
    context "existing stolen_bike_listing" do
      let!(:stolen_bike_listing) { StolenBikeListing.create(group: "constru", line: 12) }
      it "updates existing one" do
        expect(StolenBikeListing.count).to eq 1
        expect(instance.perform("constru", 12, header_values(row))&.id).to eq stolen_bike_listing.id
        expect(instance.perform("constru", 12, header_values(row))&.id).to eq stolen_bike_listing.id
        expect(StolenBikeListing.count).to eq 1
        expect(stolen_bike_listing.reload.manufacturer_id).to eq manufacturer.id
      end
    end
    context "skip_storing" do
      let(:mostly_empty_row) do
        {color: "",
         manufacturer: "blank",
         bike: "yes",
         model: " ",
         listing_text: ""}
      end
      it "is nil" do
        expect(StolenBikeListing.count).to eq 0
        # Not bike column
        expect(instance.perform("constru", 12, header_values(row.merge(bike: "No")))).to be_blank
        expect(instance.perform("constru", 12, header_values(row.merge(bike: "Raffle")))).to be_blank
        expect(instance.perform("constru", 12, header_values(row.merge(mostly_empty_row)))).to be_blank
        expect(StolenBikeListing.count).to eq 0
      end
    end
    context "repost" do
      # At least for now!
      it "is nil" do
        expect(StolenBikeListing.count).to eq 0
        expect(instance.perform("constru", 12, header_values(row.merge(repost: "110.11")))).to be_blank
        expect(StolenBikeListing.count).to eq 0
      end
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
        purple_target = black_target.merge(secondary_frame_color_id: Color.friendly_find_id("purple"))
        expect(instance.color_attrs("Black/Purple")).to eq purple_target
        expect(instance.color_attrs("Blk/Purpl")).to eq purple_target
        # And test with 3 colors
        expect(Color.friendly_find_id("silver")).to be_present # Sanity check
        expect(instance.color_attrs("Blk/Purpl/silver")).to eq purple_target.merge(tertiary_frame_color_id: Color.friendly_find_id("silver"))
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

  describe "listed_at" do
  end
end
