class AddCardIdToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :cardId, :integer
  end
end
