class SwitchMembershipRoleToBeEnum < ActiveRecord::Migration[6.1]
  def change
    rename_column :memberships, :role, :role_string
    add_column :memberships, :role, :integer
  end
end
