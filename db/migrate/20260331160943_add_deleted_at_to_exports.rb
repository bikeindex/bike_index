class AddDeletedAtToExports < ActiveRecord::Migration[8.1]
  def change
    add_column :exports, :deleted_at, :datetime
  end
end
