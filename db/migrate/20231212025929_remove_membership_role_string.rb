class RemoveMembershipRoleString < ActiveRecord::Migration[6.1]
  def change
    remove_column :memberships, :role_string, :string
  end
end
