class CreateEmailBans < ActiveRecord::Migration[8.0]
  def change
    create_table :email_bans do |t|
      t.references :user, index: true, foreign_key: false
      t.references :user_email, index: true, foreign_key: false
      t.datetime :start_at
      t.datetime :end_at
      t.integer :reason

      t.timestamps
    end
  end
end
