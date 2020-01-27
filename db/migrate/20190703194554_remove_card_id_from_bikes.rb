class RemoveCardIdFromBikes < ActiveRecord::Migration[4.2]
  def change
    remove_column :bikes, :card_id, :integer
  end
end
