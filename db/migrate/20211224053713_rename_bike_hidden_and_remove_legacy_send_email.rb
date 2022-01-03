class RenameBikeHiddenAndRemoveLegacySendEmail < ActiveRecord::Migration[5.2]
  def change
    remove_column :ownerships, :legacy_send_email, :boolean
    remove_column :bikes, :current_creation_state_id, :integer
    rename_column :bikes, :hidden, :user_hidden
  end
end
