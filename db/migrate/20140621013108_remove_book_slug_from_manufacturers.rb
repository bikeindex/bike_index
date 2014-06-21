class RemoveBookSlugFromManufacturers < ActiveRecord::Migration
  def up
    remove_column :manufacturers, :book_slug
  end

  def down
    add_column :manufacturers, :book_slug, :string
  end
end
