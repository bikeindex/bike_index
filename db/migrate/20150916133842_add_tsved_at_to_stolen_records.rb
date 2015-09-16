class AddTsvedAtToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :tsved_at, :datetime
  end
end
