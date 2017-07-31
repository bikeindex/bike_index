class AddRecoveredAndRecoveryTokensToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :recovered_link_token, :text
    add_column :stolen_records, :recovered_confirmation_token, :text
    add_column :stolen_records, :recovered, :boolean, default: false, null: false
  end
end
