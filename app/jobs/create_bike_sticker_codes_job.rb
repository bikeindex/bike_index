class CreateBikeStickerCodesJob < ApplicationJob
  def perform(id, number_to_create, initial_code_integer = nil)
    bike_sticker_batch = BikeStickerBatch.find(id)
    created_count = bike_sticker_batch.bike_stickers.count
    bike_sticker_batch.create_codes(number_to_create.to_i - created_count,
      initial_code_integer: initial_code_integer)
  end
end
