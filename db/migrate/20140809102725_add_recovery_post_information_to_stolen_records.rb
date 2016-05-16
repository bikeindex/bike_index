class AddRecoveryPostInformationToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolenRecords, :recovery_posted, :boolean, default: false
    add_column :stolenRecords, :recovery_tweet, :text
    add_column :stolenRecords, :recovery_share, :text
  end
end
