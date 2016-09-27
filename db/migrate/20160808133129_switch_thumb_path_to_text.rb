class SwitchThumbPathToText < ActiveRecord::Migration
  def change
    change_column :bikes, :thumb_path, :text
  end
end
