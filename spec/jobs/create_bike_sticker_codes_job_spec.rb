require "rails_helper"

RSpec.describe CreateBikeStickerCodesJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let!(:bike_sticker_batch) { FactoryBot.create(:bike_sticker_batch, prefix: "XX") }

    it "creates" do
      expect do
        instance.perform(bike_sticker_batch.id, 2, 10)
      end.to change(BikeSticker, :count).by 2
      bike_sticker_batch.reload
      expect(bike_sticker_batch.bike_stickers.pluck(:code).sort).to eq(%w[XX10 XX11])
    end

    context "a sticker already exists" do
      let!(:bike_sticker1) { FactoryBot.create(:bike_sticker, code: "XX10", bike_sticker_batch: bike_sticker_batch) }
      it "creates 1 less" do
        expect do
          instance.perform(bike_sticker_batch.id, 2, 10)
        end.to change(BikeSticker, :count).by 1
        bike_sticker_batch.reload
        expect(bike_sticker_batch.bike_stickers.pluck(:code).sort).to eq(%w[XX10 XX11])
      end
    end
  end
end
