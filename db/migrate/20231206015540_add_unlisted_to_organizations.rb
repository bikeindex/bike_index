class AddUnlistedToOrganizations < ActiveRecord::Migration[6.1]
  def change
    add_column :organizations, :unlisted, :boolean, default: false
  end
end
