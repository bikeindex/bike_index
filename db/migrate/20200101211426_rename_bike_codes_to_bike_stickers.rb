class RenameBikeCodesToBikeStickers < ActiveRecord::Migration
  def change
    rename_table :bike_codes, :bike_stickers
  end
end
