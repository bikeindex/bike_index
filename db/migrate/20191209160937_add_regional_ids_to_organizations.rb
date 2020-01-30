class AddRegionalIdsToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :regional_ids, :jsonb
  end
end
