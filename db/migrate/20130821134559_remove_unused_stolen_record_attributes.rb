class RemoveUnusedStolenRecordAttributes < ActiveRecord::Migration
  def up
    remove_column :stolen_records, :location_id
    remove_column :stolen_records, :police_report_information
    remove_column :stolen_records, :locking_description_id
    remove_column :stolen_records, :police_report_filed
  end

  def down
    add_column :stolen_records, :location_id, :integer
    add_column :stolen_records, :police_report_information, :text
    add_column :stolen_records, :locking_description_id, :integer
    remove_column :stolen_records, :police_report_filed, :boolean
  end
end
