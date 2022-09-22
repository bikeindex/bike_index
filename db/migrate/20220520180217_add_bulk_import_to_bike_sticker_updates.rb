class AddBulkImportToBikeStickerUpdates < ActiveRecord::Migration[6.1]
  def change
    add_reference :bike_sticker_updates, :bulk_import, index: true
  end
end
