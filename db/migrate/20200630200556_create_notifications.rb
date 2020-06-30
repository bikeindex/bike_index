class CreateNotifications < ActiveRecord::Migration[5.2]
  def change
    create_table :notifications do |t|
      t.references :user
      t.integer :kind
      t.string :delivery_status

      t.timestamps
    end
  end
end
