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
      expect(bike_sticker_batch.code_number_length_or_default).to eq 4
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
      expect(bike_sticker_batch.code_number_length_or_default).to eq 5

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
      expect(bike_sticker_batch.bike_stickers.pluck(:code)).to match_array(target_codes + %w[XD10002 XD10003 XD00012])
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
end
