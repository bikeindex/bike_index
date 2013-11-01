class RemoveSeatTubeSizeFromBikes < ActiveRecord::Migration
  def up
    remove_column :bikes, :seat_tube_length
    remove_column :bikes, :seat_tube_length_in_cm
  end

  def down
    add_column :bikes, :seat_tube_length, :string
    add_column :bikes, :seat_tube_length_in_cm, :boolean
  end
end
