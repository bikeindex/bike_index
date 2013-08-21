class AddingBetterFieldsToStolenRecord < ActiveRecord::Migration
  def change
    add_column :stolen_records, :police_report_number, :string
    add_column :stolen_records, :locking_description, :string
    add_column :stolen_records, :lock_defeat_description, :string
  end
end
