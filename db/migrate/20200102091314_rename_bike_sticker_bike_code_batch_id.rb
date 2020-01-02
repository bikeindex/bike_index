class RenameBikeStickerBikeCodeBatchId < ActiveRecord::Migration
  def change
    rename_column :bike_stickers, :bike_code_batch_id, :bike_sticker_batch_id
  end
end
