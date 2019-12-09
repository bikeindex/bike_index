class AddRegionalIdsToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :regional_ids, :jsonb
  end
end
