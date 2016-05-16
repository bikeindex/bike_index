class AddCurrentStolenRecordIdToBike < ActiveRecord::Migration
  def change
    add_column :bikes, :current_stolenRecord_id, :integer
  end
end
