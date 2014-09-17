class AddIndexToStolenRecordsLatLong < ActiveRecord::Migration
  def change
    add_index :stolen_records, [:latitude, :longitude]
  end
end
