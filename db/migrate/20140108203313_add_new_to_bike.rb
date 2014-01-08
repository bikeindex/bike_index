class AddNewToBike < ActiveRecord::Migration
  def change
    add_column :bikes, :registered_new, :boolean
  end
end
