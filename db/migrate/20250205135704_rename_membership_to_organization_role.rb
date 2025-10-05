class RenameMembershipToOrganizationRole < ActiveRecord::Migration[8.0]
  def change
    rename_table :memberships, :organization_roles
  end
end
