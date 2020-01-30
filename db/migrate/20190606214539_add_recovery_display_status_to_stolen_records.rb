class AddRecoveryDisplayStatusToStolenRecords < ActiveRecord::Migration[4.2]
  def change
    add_column :stolen_records, :recovery_display_status, :integer, default: 0
  end
end
