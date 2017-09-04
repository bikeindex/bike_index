class AddRecoveryLinkTokenToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :recovery_link_token, :text
  end
end
