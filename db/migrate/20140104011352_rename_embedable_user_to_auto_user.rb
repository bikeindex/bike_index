class RenameEmbedableUserToAutoUser < ActiveRecord::Migration
  def up
    rename_column :organizations, :embedable_user_id, :auto_user_id
  end

  def down
    rename_column :organizations, :auto_user_id, :embedable_user_id
  end
end
