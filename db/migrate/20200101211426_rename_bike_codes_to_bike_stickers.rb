class RenameBikeCodesToBikeStickers < ActiveRecord::Migration[4.2]
  def change
    rename_table :bike_codes, :bike_stickers
    rename_table :bike_code_batches, :bike_sticker_batches
    rename_column :bike_stickers, :bike_code_batch_id, :bike_sticker_batch_id
  end
end
