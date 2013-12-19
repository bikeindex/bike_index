class RenameLogoLocationToLogoOnManufacturers < ActiveRecord::Migration
  def up
    rename_column :manufacturers, :logo_location, :logo
  end

  def down
    rename_column :manufacturers, :logo, :logo_location
  end
end
