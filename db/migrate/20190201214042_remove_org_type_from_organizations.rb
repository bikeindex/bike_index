class RemoveOrgTypeFromOrganizations < ActiveRecord::Migration
  def change
    remove_column :organizations, :org_type, :string
  end
end
