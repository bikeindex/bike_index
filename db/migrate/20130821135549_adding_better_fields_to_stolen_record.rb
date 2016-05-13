class AddingBetterFieldsToStolenRecord < ActiveRecord::Migration
  def change
    add_column :stolenRecords, :police_report_number, :string
    add_column :stolenRecords, :locking_description, :string
    add_column :stolenRecords, :lock_defeat_description, :string
  end
end
