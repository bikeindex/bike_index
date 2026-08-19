class AddPriorityToOrganizationRoles < ActiveRecord::Migration[8.1]
  # Existing roles are numbered by Backfills::OrganizationRolePriorityJob
  def change
    add_column :organization_roles, :priority, :integer, default: 0, null: false
  end
end
