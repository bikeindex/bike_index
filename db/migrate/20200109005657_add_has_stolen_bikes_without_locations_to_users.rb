class AddHasStolenBikesWithoutLocationsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :has_stolen_bikes_without_locations, :boolean, default: false
  end
end
