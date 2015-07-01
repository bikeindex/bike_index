class AddManufacturerLogoSourceToManufacturers < ActiveRecord::Migration
  def change
    add_column :manufacturers, :logo_source, :string
  end
end
