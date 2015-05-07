class AddIsEmailableToUsers < ActiveRecord::Migration
  def change
    add_column :users, :is_emailable, :boolean, default: false, null: false
  end
end
