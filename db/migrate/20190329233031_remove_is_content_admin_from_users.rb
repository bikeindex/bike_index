class RemoveIsContentAdminFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :is_content_admin, :boolean
  end
end
