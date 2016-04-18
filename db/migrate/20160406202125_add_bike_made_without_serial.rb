class AddBikeMadeWithoutSerial < ActiveRecord::Migration
  def up
    add_column :bikes, :made_without_serial, :boolean, default: false, null: false
  end

  def down
    remove_column :bikes, :made_without_serial
  end
end
