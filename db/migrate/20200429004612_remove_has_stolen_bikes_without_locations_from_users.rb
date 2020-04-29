class RemoveHasStolenBikesWithoutLocationsFromUsers < ActiveRecord::Migration[5.2]
  def change
    remove_column :users, :has_stolen_bikes_without_locations, :boolean
  end
end
