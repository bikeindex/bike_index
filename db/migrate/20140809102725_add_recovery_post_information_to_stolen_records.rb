class AddRecoveryPostInformationToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :recovery_posted, :boolean, default: false
    add_column :stolen_records, :recovery_tweet, :text
    add_column :stolen_records, :recovery_share, :text
  end
end
