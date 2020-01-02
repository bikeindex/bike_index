class RenameBikeCodeBatchesToBikeStickerBatches < ActiveRecord::Migration
  def change
    rename_table :bike_code_batches, :bike_sticker_batches
  end
end
