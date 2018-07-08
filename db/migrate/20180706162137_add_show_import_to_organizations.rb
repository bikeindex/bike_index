class AddShowImportToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :show_bulk_import, :boolean, default: false
  end
end
