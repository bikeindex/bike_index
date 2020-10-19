class RemoveRegisteredNewFromBikes < ActiveRecord::Migration[5.2]
  def change
    remove_column :bikes, :registered_new, :boolean
  end
end
