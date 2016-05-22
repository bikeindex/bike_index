class CreateUserEmails < ActiveRecord::Migration
  def change
    create_table :user_emails do |t|
      t.string :email
      t.integer :user_id
      t.integer :old_user_id
      t.text :confirmation_token
      t.timestamps
    end
    add_index :user_emails, :user_id
  end
end
