class AddUserEmailToEmailBans < ActiveRecord::Migration[8.1]
  def change
    add_reference :email_bans, :user_email, index: true
  end
end
