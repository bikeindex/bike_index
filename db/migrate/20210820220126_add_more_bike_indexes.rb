class AddMoreBikeIndexes < ActiveRecord::Migration[5.2]
  def change
    add_index :bikes, :example
    add_index :bikes, :hidden
    add_index :bikes, :status
  end
end
