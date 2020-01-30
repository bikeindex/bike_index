class RenameStolenRecordDateRecoveredToRecoveredAt < ActiveRecord::Migration[4.2]
  def change
    rename_column :stolen_records, :date_recovered, :recovered_at
    rename_column :recovery_displays, :date_recovered, :recovered_at
  end
end
