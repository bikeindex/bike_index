class CreateUserBans < ActiveRecord::Migration[6.1]
  def change
    create_table :user_bans do |t|
      t.references :user
      t.references :creator
      t.integer :reason
      t.text :description

      t.datetime :deleted_at

      t.timestamps
    end
  end
end
