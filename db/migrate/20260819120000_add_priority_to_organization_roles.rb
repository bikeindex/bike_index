class AddPriorityToOrganizationRoles < ActiveRecord::Migration[8.1]
  def up
    add_column :organization_roles, :priority, :integer, default: 0, null: false
    # Backfill in the order the roles were created, matching what new roles now calculate
    execute <<~SQL
      UPDATE organization_roles SET priority = ordered.position
      FROM (
        SELECT id, row_number() OVER (PARTITION BY user_id ORDER BY created_at, id) - 1 AS position
        FROM organization_roles WHERE user_id IS NOT NULL
      ) ordered
      WHERE organization_roles.id = ordered.id
    SQL
  end

  def down
    remove_column :organization_roles, :priority
  end
end
