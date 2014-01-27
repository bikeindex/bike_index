class AddSerialNormalizedToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :serial_normalized, :string
  end
end
