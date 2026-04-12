class AddIndexToUserEmailsOnEmailWhereConfirmed < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :user_emails, :email, where: "confirmation_token IS NULL", name: :index_user_emails_on_email_confirmed, algorithm: :concurrently
  end
end
