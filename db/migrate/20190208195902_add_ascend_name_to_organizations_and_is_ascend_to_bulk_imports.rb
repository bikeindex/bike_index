class AddAscendNameToOrganizationsAndIsAscendToBulkImports < ActiveRecord::Migration
  def change
    add_column :organizations, :ascend_name, :string
    add_column :bulk_imports, :is_ascend, :boolean, default: false
  end
end
