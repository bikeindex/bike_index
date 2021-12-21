class AddSkipEmailToOwnerships < ActiveRecord::Migration[5.2]
  def change
    add_column :ownerships, :skip_email, :boolean, default: false
    rename_column :ownerships, :send_email, :legacy_send_email
  end
end
