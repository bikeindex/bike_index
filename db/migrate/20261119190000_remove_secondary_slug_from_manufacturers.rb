class RemoveSecondarySlugFromManufacturers < ActiveRecord::Migration[8.1]
  def change
    remove_column :manufacturers, :secondary_slug, :string
  end
end
