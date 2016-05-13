class AddTsvedAtToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolenRecords, :tsved_at, :datetime
  end
end
