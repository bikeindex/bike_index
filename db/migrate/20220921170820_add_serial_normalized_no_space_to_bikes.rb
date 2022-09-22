class AddSerialNormalizedNoSpaceToBikes < ActiveRecord::Migration[6.1]
  def change
    add_column :bikes, :serial_normalized_no_space, :string
  end
end
