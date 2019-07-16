class RemoveHasNoSerialFromBikes < ActiveRecord::Migration
  def change
    remove_column :bikes, :has_no_serial, :boolean
  end
end
