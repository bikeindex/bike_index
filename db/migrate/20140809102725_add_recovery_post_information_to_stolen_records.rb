class AddRecoveryPostInformationToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_record, :recovery_posted, :boolean, default: false
    add_column :stolen_record, :recovery_tweet, :text
    add_column :stolen_record, :recovery_share, :text
  end
end
