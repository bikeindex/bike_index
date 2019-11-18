class DropStolenLatLongFromBikes < ActiveRecord::Migration
  def change
    remove_column :bikes, :stolen_lat, :float
    remove_column :bikes, :stolen_long, :float
  end
end
