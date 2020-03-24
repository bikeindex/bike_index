class AddAddressColumnToGeocodeableModels < ActiveRecord::Migration[5.2]
  def change
    add_column :bikes, :address, :string
    add_column :locations, :address, :string
    add_column :stolen_records, :address, :string
    add_column :users, :address, :string
  end
end
