class AddPreviousSlugsToManufacturers < ActiveRecord::Migration[8.1]
  def change
    add_column :manufacturers, :previous_slugs, :string, array: true, default: [], null: false
  end
end
