class RemoveCardIdFromBikes < ActiveRecord::Migration
  def change
    remove_column :bikes, :card_id, :integer
  end
end
