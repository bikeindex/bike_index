class AddAddressColumnToGeocodeableModels < ActiveRecord::Migration[5.2]
  def change
    add_column :bikes, :geocode_address, :string
    add_column :locations, :geocode_address, :string
    add_column :mail_snippets, :geocode_address, :string
    add_column :stolen_records, :geocode_address, :string
    add_column :twitter_accounts, :geocode_address, :string
    add_column :users, :geocode_address, :string
  end
end
