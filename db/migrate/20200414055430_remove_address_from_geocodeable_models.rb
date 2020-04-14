class RemoveAddressFromGeocodeableModels < ActiveRecord::Migration[5.2]
  def change
    remove_column :bikes, :address, :string
    remove_column :locations, :address, :string
    remove_column :stolen_records, :address, :string
    remove_column :users, :address, :string
  end
end
