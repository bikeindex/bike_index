class AddContentAdminToUsers < ActiveRecord::Migration
  def change
    add_column :users, :is_content_admin, :boolean, default: false, null: false
  end
end
