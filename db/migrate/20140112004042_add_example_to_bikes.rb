class AddExampleToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :example, :boolean, default: false, null: false
  end
end
