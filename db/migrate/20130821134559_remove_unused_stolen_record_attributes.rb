class RemoveUnusedStolenRecordAttributes < ActiveRecord::Migration
  def up
    remove_column :stolenRecords, :location_id
    remove_column :stolenRecords, :police_report_information
    remove_column :stolenRecords, :locking_description_id
    remove_column :stolenRecords, :police_report_filed
  end

  def down
    add_column :stolenRecords, :location_id, :integer
    add_column :stolenRecords, :police_report_information, :text
    add_column :stolenRecords, :locking_description_id, :integer
    remove_column :stolenRecords, :police_report_filed, :boolean
  end
end
