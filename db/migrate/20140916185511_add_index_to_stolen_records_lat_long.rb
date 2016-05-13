class AddIndexToStolenRecordsLatLong < ActiveRecord::Migration
  def change
    add_index :stolenRecords, [:latitude, :longitude]
  end
end
