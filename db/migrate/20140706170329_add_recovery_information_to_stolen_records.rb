class AddRecoveryInformationToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolenRecords, :date_recovered, :datetime
    add_column :stolenRecords, :recovered_description, :text
    add_column :stolenRecords, :index_helped_recovery, :boolean, default: false, null: false
    add_column :stolenRecords, :can_share_recovery, :boolean, default: false, null: false
    add_column :stolenRecords, :recovery_share_approved, :boolean, default: false, null: false
    add_column :stolenRecords, :recovery_share_ignore, :boolean, default: false, null: false
  end
end
