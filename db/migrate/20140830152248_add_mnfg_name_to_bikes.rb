class AddMnfgNameToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :mnfg_name, :string
  end
end
