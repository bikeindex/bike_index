class AddEmbedableUserToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :embedable_user_id, :integer
  end
end
