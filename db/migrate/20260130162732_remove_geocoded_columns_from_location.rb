class RemoveGeocodedColumnsFromLocation < ActiveRecord::Migration[8.1]
  def change
    remove_column :locations, :city, :string
    remove_column :locations, :neighborhood, :string
    remove_column :locations, :street, :string
    remove_column :locations, :zipcode, :string
    remove_column :locations, :country_id, :integer
    remove_column :locations, :state_id, :integer
  end
end
