class AddLegacySlugToManufacturers < ActiveRecord::Migration[8.1]
  def change
    add_column :manufacturers, :legacy_slug, :string
  end
end
