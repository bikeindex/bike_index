class AddDisplayIdAndStatusToImpoundRecords < ActiveRecord::Migration[5.2]
  def change
    add_column :impound_records, :display_id, :bigint
    add_column :impound_records, :status, :integer, default: 0
    rename_column :impound_records, :retrieved_at, :resolved_at
  end
end
