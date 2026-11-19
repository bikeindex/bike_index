class AddLegacySlugToManufacturers < ActiveRecord::Migration[8.1]
  def change
    add_column :manufacturers, :legacy_slug, :string
    up_only { execute "UPDATE manufacturers SET legacy_slug = slug" }
  end
end
