class RemoveGeocodableAttributesFromMailSnippets < ActiveRecord::Migration[8.1]
  def change
    remove_column :mail_snippets, :latitude, :float
    remove_column :mail_snippets, :longitude, :float
    remove_column :mail_snippets, :proximity_radius, :integer
    remove_column :mail_snippets, :is_location_triggered, :boolean, default: false, null: false
    remove_column :mail_snippets, :city, :string
    remove_column :mail_snippets, :street, :string
    remove_column :mail_snippets, :zipcode, :string
    remove_column :mail_snippets, :neighborhood, :string
    remove_column :mail_snippets, :country_id, :bigint
    remove_column :mail_snippets, :state_id, :bigint
    remove_index :mail_snippets, :country_id, if_exists: true
    remove_index :mail_snippets, :state_id, if_exists: true
  end
end
