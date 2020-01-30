class RemoveIsContentAdminFromUsers < ActiveRecord::Migration[4.2]
  def change
    remove_column :users, :is_content_admin, :boolean
  end
end
