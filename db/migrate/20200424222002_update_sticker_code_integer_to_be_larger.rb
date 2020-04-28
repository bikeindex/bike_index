class UpdateStickerCodeIntegerToBeLarger < ActiveRecord::Migration[5.2]
  def change
    change_column :bike_stickers, :code_integer, :bigint
  end
end
