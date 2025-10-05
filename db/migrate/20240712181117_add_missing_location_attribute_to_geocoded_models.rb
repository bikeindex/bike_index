class AddMissingLocationAttributeToGeocodedModels < ActiveRecord::Migration[6.1]
  def change
    add_column :bikes, :neighborhood, :string
    add_column :locations, :neighborhood, :string
    add_column :mail_snippets, :neighborhood, :string
    add_column :users, :neighborhood, :string
  end
end
