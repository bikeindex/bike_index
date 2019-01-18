class AddAddressToUsers < ActiveRecord::Migration
  def change
    add_column :users, :latitude, :float
    add_column :users, :longitude, :float
    add_column :users, :street, :string
    add_column :users, :city, :string
    add_column :users, :country_id, :integer
    add_column :users, :state_id, :integer
    remove_column :users, :has_stolen_bikes, :boolean # Drop unused attribute
  end
end
