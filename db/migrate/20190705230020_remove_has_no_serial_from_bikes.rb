class RemoveHasNoSerialFromBikes < ActiveRecord::Migration[4.2]
  def change
    remove_column :bikes, :has_no_serial, :boolean
  end
end
