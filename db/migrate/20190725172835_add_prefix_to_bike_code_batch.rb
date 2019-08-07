class AddPrefixToBikeCodeBatch < ActiveRecord::Migration
  def change
    add_column :bike_code_batches, :prefix, :string
  end
end
