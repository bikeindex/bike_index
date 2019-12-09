class AddSubOrganizationsToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :sub_organization_ids, :jsonb
    rename_column :organizations, :child_ids, :legacy_child_ids
  end
end
