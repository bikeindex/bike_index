class AddXyzCodeToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :xyz_code, :string
    add_index :bikes, :xyz_code, :unique => true
  end
end
