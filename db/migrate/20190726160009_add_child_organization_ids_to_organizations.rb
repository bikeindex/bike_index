class AddChildOrganizationIdsToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :child_ids, :jsonb
  end
end
