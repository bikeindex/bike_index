class AddChildOrganizationIdsToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :child_ids, :jsonb
  end
end
