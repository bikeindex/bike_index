class AddShownToLocations < ActiveRecord::Migration
  def change
    add_column :locations, :shown, :boolean, default: false
  end
end
