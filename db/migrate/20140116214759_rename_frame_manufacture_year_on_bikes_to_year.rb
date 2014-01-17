class RenameFrameManufactureYearOnBikesToYear < ActiveRecord::Migration
  def up
    rename_column :bikes, :frame_manufacture_year, :year
  end

  def down
    rename_column :bikes, :year, :frame_manufacture_year
  end
end
