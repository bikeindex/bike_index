class AddDeletedAtToBikes < ActiveRecord::Migration[4.2]
  def change
    add_column :bikes, :deleted_at, :datetime
    add_index :bikes, :deleted_at
  end
end
