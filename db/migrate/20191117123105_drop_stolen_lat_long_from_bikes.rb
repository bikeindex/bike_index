class DropStolenLatLongFromBikes < ActiveRecord::Migration[4.2]
  def change
    remove_column :bikes, :stolen_lat, :float
    remove_column :bikes, :stolen_long, :float
  end
end
