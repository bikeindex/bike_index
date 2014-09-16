class AddHiddenOptionToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :hidden, :boolean, default: false, null: false
  end
end
