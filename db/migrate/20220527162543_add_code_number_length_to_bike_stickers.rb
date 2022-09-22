class AddCodeNumberLengthToBikeStickers < ActiveRecord::Migration[6.1]
  def change
    add_column :bike_stickers, :code_number_length, :integer
  end
end
