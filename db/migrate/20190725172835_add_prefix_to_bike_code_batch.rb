class AddPrefixToBikeCodeBatch < ActiveRecord::Migration[4.2]
  def change
    add_column :bike_code_batches, :prefix, :string
  end
end
