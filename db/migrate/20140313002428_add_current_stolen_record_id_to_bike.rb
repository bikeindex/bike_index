class AddCurrentStolenRecordIdToBike < ActiveRecord::Migration
  def change
    add_column :bikes, :current_stolen_record_id, :integer
  end
end
