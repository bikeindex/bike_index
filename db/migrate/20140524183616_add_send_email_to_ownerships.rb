class AddSendEmailToOwnerships < ActiveRecord::Migration
  def change
    add_column :ownerships, :send_email, :boolean, default: true, null: true
  end
end
