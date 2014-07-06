class AddRecoveryInformationToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :date_recovered, :datetime
    add_column :stolen_records, :recovered_description, :text
    add_column :stolen_records, :index_helped_recovery, :boolean, default: false, null: false
    add_column :stolen_records, :can_share_recovery, :boolean, default: false, null: false
    add_column :stolen_records, :recovery_share_approved, :boolean, default: false, null: false
    add_column :stolen_records, :recovery_share_ignore, :boolean, default: false, null: false
  end
end
