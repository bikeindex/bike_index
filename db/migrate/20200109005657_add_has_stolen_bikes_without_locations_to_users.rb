class AddHasStolenBikesWithoutLocationsToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :has_stolen_bikes_without_locations, :boolean, default: false
  end
end
