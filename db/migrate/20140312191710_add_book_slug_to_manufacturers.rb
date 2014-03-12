class AddBookSlugToManufacturers < ActiveRecord::Migration
  def change
    add_column :manufacturers, :book_slug, :string
  end
end
