class AddTwitterHandleToManufacturers < ActiveRecord::Migration[5.2]
  def change
    add_column :manufacturers, :twitter_name, :string
  end
end
