class RemoveOrgTypeFromOrganizations < ActiveRecord::Migration[4.2]
  def change
    remove_column :organizations, :org_type, :string
  end
end
