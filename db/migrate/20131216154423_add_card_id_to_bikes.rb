class AddCardIdToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :card_id, :integer
  end
end
