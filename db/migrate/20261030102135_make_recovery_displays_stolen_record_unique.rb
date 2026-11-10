class MakeRecoveryDisplaysStolenRecordUnique < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :recovery_displays, :stolen_record_id, unique: true,
      name: :index_recovery_displays_on_stolen_record_id_unique, algorithm: :concurrently
    remove_index :recovery_displays, :stolen_record_id,
      name: :index_recovery_displays_on_stolen_record_id, algorithm: :concurrently
  end
end
