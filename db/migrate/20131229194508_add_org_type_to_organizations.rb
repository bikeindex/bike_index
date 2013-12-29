class AddOrgTypeToOrganizations < ActiveRecord::Migration
  def up
    add_column :organizations, :org_type, :string, :default => "shop", :null => false
    remove_column :organizations, :is_police
  end
  def down
    remove_column :organizations, :org_type
    add_column :organizations, :is_police, :boolean
  end
end
