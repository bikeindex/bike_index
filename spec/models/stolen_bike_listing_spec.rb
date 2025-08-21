# == Schema Information
#
# Table name: stolen_bike_listings
#
#  id                       :bigint           not null, primary key
#  amount_cents             :integer
#  currency_enum            :integer
#  data                     :jsonb
#  frame_model              :text
#  frame_size               :string
#  frame_size_number        :float
#  frame_size_unit          :string
#  group                    :integer
#  line                     :integer
#  listed_at                :datetime
#  listing_order            :integer
#  listing_text             :text
#  manufacturer_other       :string
#  mnfg_name                :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  bike_id                  :bigint
#  initial_listing_id       :bigint
#  manufacturer_id          :bigint
#  primary_frame_color_id   :bigint
#  secondary_frame_color_id :bigint
#  tertiary_frame_color_id  :bigint
#
# Indexes
#
#  index_stolen_bike_listings_on_bike_id                   (bike_id)
#  index_stolen_bike_listings_on_initial_listing_id        (initial_listing_id)
#  index_stolen_bike_listings_on_manufacturer_id           (manufacturer_id)
#  index_stolen_bike_listings_on_primary_frame_color_id    (primary_frame_color_id)
#  index_stolen_bike_listings_on_secondary_frame_color_id  (secondary_frame_color_id)
#  index_stolen_bike_listings_on_tertiary_frame_color_id   (tertiary_frame_color_id)
#
require "rails_helper"

RSpec.describe StolenBikeListing, type: :model do
  it_behaves_like "amountable"
  it_behaves_like "currencyable"

  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color) }

  describe "amount" do
    let(:stolen_bike_listing) { FactoryBot.create(:stolen_bike_listing, amount_cents: 420_000, currency: "MXN") }
    let!(:exchange_rate) { FactoryBot.create(:exchange_rate, from: "MXN", to: "USD", rate: 0.047) }
    it "is in pesos" do
      expect(stolen_bike_listing.amount_formatted).to eq "$4,200.00"
      expect(stolen_bike_listing.data["amount_cents_usd"]).to eq 19740
      expect(stolen_bike_listing.amount_usd_formatted).to eq "$197"
    end
  end

  describe "searchable" do
    let(:interpreted_params) { BikeSearchable.searchable_interpreted_params(query_params) }
    context "color_ids of primary, secondary and tertiary" do
      let(:color2) { FactoryBot.create(:color) }
      let(:stolen_bike_listing1) { FactoryBot.create(:stolen_bike_listing, primary_frame_color: color, listed_at: Time.current - 3.months) }
      let(:stolen_bike_listing2) { FactoryBot.create(:stolen_bike_listing, secondary_frame_color: color, tertiary_frame_color: color2, listed_at: Time.current - 2.weeks) }
      let(:stolen_bike_listing3) { FactoryBot.create(:stolen_bike_listing, tertiary_frame_color: color, manufacturer: manufacturer) }
      let(:all_color_ids) do
        [
          stolen_bike_listing1.primary_frame_color_id,
          stolen_bike_listing2.primary_frame_color_id,
          stolen_bike_listing3.primary_frame_color_id,
          stolen_bike_listing1.secondary_frame_color_id,
          stolen_bike_listing2.secondary_frame_color_id,
          stolen_bike_listing3.secondary_frame_color_id,
          stolen_bike_listing1.tertiary_frame_color_id,
          stolen_bike_listing2.tertiary_frame_color_id,
          stolen_bike_listing3.tertiary_frame_color_id
        ]
      end
      before do
        expect(all_color_ids.count(color.id)).to eq 3 # Each bike has color only once
      end
      context "single color" do
        let(:query_params) { {colors: [color.id], stolenness: "all"} }
        it "matches bikes with the given color" do
          expect(stolen_bike_listing1.listing_order < stolen_bike_listing2.listing_order).to be_truthy
          expect(stolen_bike_listing2.listing_order < stolen_bike_listing3.listing_order).to be_truthy
          expect(StolenBikeListing.search(interpreted_params).pluck(:id)).to eq([stolen_bike_listing3.id, stolen_bike_listing2.id, stolen_bike_listing1.id])
        end
      end
      context "second color" do
        let(:query_params) { {colors: [color.id, color2.id], stolenness: "all"} }
        it "matches just the bike with both colors" do
          expect(StolenBikeListing.search(interpreted_params).pluck(:id)).to eq([stolen_bike_listing2.id])
        end
      end
      context "and manufacturer_id" do
        let(:query_params) { {colors: [color.id], manufacturer: manufacturer.id, stolenness: "all"} }
        it "matches just the bike with the matching manufacturer" do
          expect(StolenBikeListing.search(interpreted_params).pluck(:id)).to eq([stolen_bike_listing3.id])
        end
      end
    end
  end

  describe "updated_photo_folder" do
    let(:stolen_bike_listing) { StolenBikeListing.new(data: {photo_folder: photo_folder}) }
    let(:photo_folder) { "Nov 20 2020_006" }
    it "puts out expected thing" do
      expect(stolen_bike_listing.updated_photo_folder).to eq "2020/11/2020-11-20_006"
    end
    context "different date" do
      let(:photo_folder) { "aug 23 2020" }
      it "deals with that too" do
        expect(stolen_bike_listing.updated_photo_folder).to eq "2020/8/2020-8-23"
      end
    end
    context "weird date" do
      let(:photo_folder) { "july7_2020_2" }
      it "deals with that too" do
        expect(stolen_bike_listing.updated_photo_folder).to eq "2020/7/2020-7-7_2"
      end
    end
    context "other weird shit" do
      let(:photo_folder) { "Feb 14 2021_OMFG" }
      it "deals with that too" do
        expect(stolen_bike_listing.updated_photo_folder).to eq "2021/2/2021-2-14_OMFG"
      end
    end
    context "other weird shit pt 2" do
      let(:photo_folder) { "Jan 9 2021_001_Extra" }
      it "deals with that too" do
        expect(stolen_bike_listing.updated_photo_folder).to eq "2021/1/2021-1-9_001_Extra"
      end
    end
    context "empty" do
      let(:photo_folder) { "" }
      it "handles it" do
        expect(stolen_bike_listing.updated_photo_folder).to be_blank
      end
    end
  end

  describe "full_photo_urls" do
    let(:photo_urls) { ["2020/6/2020-6-6_002/image-1793.png", "2020/6/2020-6-6_002/image-1787.png", "2020/6/2020-6-6_002/image-1778.png", "2020/6/2020-6-6_002/image-1789.png", "2020/6/2020-6-6_002/image-1806.png", "2020/6/2020-6-6_002/image-1807.png", "2020/6/2020-6-6_002/image-1811.png", "2020/6/2020-6-6_002/image-1805.png", "2020/6/2020-6-6_002/image-1810.png", "2020/6/2020-6-6_002/image-1809.png"] }
    let(:target) do
      [
        "image-1778.png",
        "image-1787.png",
        "image-1789.png",
        "image-1793.png",
        "image-1805.png",
        "image-1806.png",
        "image-1807.png",
        "image-1809.png",
        "image-1810.png",
        "image-1811.png"
      ]
    end
    let(:stolen_bike_listing) { StolenBikeListing.new(data: {photo_urls: photo_urls}) }
    it "responds with them in order" do
      expect(stolen_bike_listing.photo_urls[0..3]).to eq(target.map { |u| "2020/6/2020-6-6_002/#{u}" }[0..3])
      expect(stolen_bike_listing.photo_urls).to eq target.map { |u| "2020/6/2020-6-6_002/#{u}" }
      expect(stolen_bike_listing.full_photo_urls).to eq(target.map { |u| "https://files.bikeindex.org/theft-rings/2020/6/2020-6-6_002/#{u}" })
    end
  end

  describe "find_by_folder" do
    let(:color) { Color.black }
    let(:stolen_bike_listing1) { FactoryBot.create(:stolen_bike_listing, primary_frame_color: color, data: {photo_folder: "Mar 27 2021"}) }
    let(:stolen_bike_listing2) { FactoryBot.create(:stolen_bike_listing, primary_frame_color: color, data: {photo_folder: "Mar 27 2021_003"}) }
    it "finds by folder" do
      expect(stolen_bike_listing1).to be_valid
      expect(stolen_bike_listing1.updated_photo_folder).to eq "2021/3/2021-3-27"
      expect(stolen_bike_listing2).to be_valid
      expect(stolen_bike_listing2.updated_photo_folder).to eq "2021/3/2021-3-27_003"

      expect(StolenBikeListing.find_by_folder("2021/3/2021-3-27")&.id).to eq stolen_bike_listing1.id
      expect(StolenBikeListing.find_by_folder("2021/3/2021-3-27_002")&.id).to be_blank
      expect(StolenBikeListing.find_by_folder("2021/3/2021-3-27_003")&.id).to eq stolen_bike_listing2.id
      expect(StolenBikeListing.find_by_folder("2021/3/2021-3-27_004")&.id).to be_blank
    end
  end
end
