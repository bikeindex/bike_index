class CreateBikeStickerUpdates < ActiveRecord::Migration[5.2]
  def change
    create_table :bike_sticker_updates do |t|
      t.references :bike_sticker
      t.references :bike
      t.references :user
      t.references :organization

      t.boolean :pos_claim, default: false
      t.integer :kind
      t.integer :creator_kind

      t.timestamps
    end
  end
end
