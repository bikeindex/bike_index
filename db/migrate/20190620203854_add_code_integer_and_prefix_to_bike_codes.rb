class AddCodeIntegerAndPrefixToBikeCodes < ActiveRecord::Migration
  def change
    add_column :bike_codes, :code_integer, :integer
    add_column :bike_codes, :code_prefix, :string
  end
end
