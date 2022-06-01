require "rails_helper"

RSpec.describe BikeStickerBatch, type: :model do
  describe "factory" do
    let(:bike_sticker_batch) { FactoryBot.create(:bike_sticker_batch) }
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker, bike_sticker_batch: bike_sticker_batch) }
    it "works" do
      expect(bike_sticker_batch.bike_stickers).to eq([bike_sticker])
      expect(bike_sticker.bike_sticker_batch).to eq bike_sticker_batch
    end
  end

  describe "create_codes" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:bike_sticker_batch) { FactoryBot.create(:bike_sticker_batch, prefix: "XD", code_number_length: nil, organization: organization) }
    let(:target_codes) { %w[XD9999 XD10000 XD10001] }
    it "create_codes works and derives last code" do
      bike_sticker_batch.update_column :updated_at, Time.current - 1.hour
      expect(bike_sticker_batch.updated_at).to be < Time.current - 50.minutes
      expect(bike_sticker_batch.calculated_code_number_length).to eq 4
      expect(bike_sticker_batch.bike_stickers.count).to eq 0
      expect {
        bike_sticker_batch.create_codes(3, initial_code_integer: 9999)
      }.to change(BikeSticker, :count).by 3
      bike_sticker_batch.reload
      expect(bike_sticker_batch.updated_at).to be_within(1.second).of Time.current
      expect(bike_sticker_batch.bike_stickers.count).to eq 3
      expect(bike_sticker_batch.bike_stickers.sticker.count).to eq 3
      expect(organization.bike_stickers.count).to eq 3
      expect(bike_sticker_batch.bike_stickers.pluck(:code)).to match_array target_codes
      expect(bike_sticker_batch.bike_stickers.pluck(:code_integer)).to match_array([9999, 10_000, 10_001])
      expect(bike_sticker_batch.calculated_code_number_length).to eq 4

      expect {
        bike_sticker_batch.create_codes(1)
      }.to change(BikeSticker, :count).by 1
      expect(bike_sticker_batch.bike_stickers.pluck(:code)).to match_array(target_codes + ["XD10002"])

      # If passed a code number that already exists, it creates the following one
      expect {
        bike_sticker_batch.create_codes(1, initial_code_integer: 10_002)
      }.to change(BikeSticker, :count).by 1
      expect(bike_sticker_batch.bike_stickers.pluck(:code)).to match_array(target_codes + %w[XD10002 XD10003])

      # It can do earlier numbers too. If doing so, it pads accordingly
      expect {
        bike_sticker_batch.create_codes(1, initial_code_integer: 12)
      }.to change(BikeSticker, :count).by 1
      expect(bike_sticker_batch.bike_stickers.pluck(:code)).to match_array(target_codes + %w[XD10002 XD10003 XD12])
      expect(bike_sticker_batch.non_sequential_integers).to eq([[12, 9999]])
    end
    context "without a prefix" do
      let(:bike_sticker_batch) { FactoryBot.create(:bike_sticker_batch, prefix: nil) }
      it "errors" do
        expect {
          bike_sticker_batch.create_codes(100)
        }.to raise_error(/prefix/i)
      end
    end
  end

  context "calculated_code_number_length" do
    it "is 4 by default" do
      expect(BikeStickerBatch.new.calculated_code_number_length).to eq 4
    end
    context "with initial_code_integer" do
      let(:bike_sticker_batch) { BikeStickerBatch.new(initial_code_integer: "012345") }
      it "is the initial_code_integer length" do
        expect(bike_sticker_batch.calculated_code_number_length).to eq 5
      end
    end
    context "with initial_code_integer" do
      let(:bike_sticker_batch) { BikeStickerBatch.new(initial_code_integer: "99999", stickers_to_create_count: 2) }
      it "is the max sticker length" do
        expect(bike_sticker_batch.calculated_code_number_length).to eq 6
      end
    end
  end

  describe "lookup with calculated_code_number_length" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:bike_sticker_batch) do
      BikeStickerBatch.create(code_number_length: 6,
        prefix: "CAL", organization: organization)
    end
    let(:bike_sticker1) { BikeSticker.order(:code_integer).first }
    let(:bike_sticker2) { BikeSticker.order(:code_integer).last }
    it "creates and finds" do
      expect(bike_sticker_batch.reload.code_number_length).to eq 6
      bike_sticker_batch.create_codes(1, initial_code_integer: 1)
      bike_sticker_batch.create_codes(1, initial_code_integer: 14106)
      expect(bike_sticker_batch.reload.bike_stickers.count).to eq 2
      expect(bike_sticker1.code).to eq "CAL1"
      expect(bike_sticker1.pretty_code).to eq "CAL 000 001"
      expect(bike_sticker2.code).to eq "CAL14106"
      expect(bike_sticker2.pretty_code).to eq "CAL 014 106"

      expect(BikeSticker.lookup("CAL 01")&.id).to eq bike_sticker1.id
      expect(BikeSticker.lookup_with_fallback("CAL 01")&.id).to eq bike_sticker1.id
      expect(BikeSticker.lookup_with_fallback("CAL 1")&.id).to eq bike_sticker1.id
      expect(BikeSticker.lookup("CAL 014 106")&.id).to eq bike_sticker2.id
      expect(BikeSticker.lookup_with_fallback("CAL 014 106")&.id).to eq bike_sticker2.id
    end
  end
end
