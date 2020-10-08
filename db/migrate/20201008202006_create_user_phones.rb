class CreateUserPhones < ActiveRecord::Migration[5.2]
  def change
    create_table :user_phones do |t|
      t.references :user
      t.string :phone
      t.string :confirmation_code
      t.datetime :confirmed_at

      t.timestamps
    end
  end
end
