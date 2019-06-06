class AddRecoveryDisplayStatusToStolenRecord < ActiveRecord::Migration
  def change
    add_column :stolen_records, :recovery_display_status, :integer, default: 0
  end
end
