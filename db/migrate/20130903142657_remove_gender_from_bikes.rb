class RemoveGenderFromBikes < ActiveRecord::Migration
  def up
    remove_column :bikes, :gender 
  end

  def down
    add_column :bikes, :gender, :string
  end
end
