class RemoveUserEmailIdFromEmailBans < ActiveRecord::Migration[8.0]
  def change
    remove_column :email_bans, :user_email_id, :bigint
  end
end
