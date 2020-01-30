class AddShowImportToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :show_bulk_import, :boolean, default: false
  end
end
