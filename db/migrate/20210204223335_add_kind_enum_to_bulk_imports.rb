class AddKindEnumToBulkImports < ActiveRecord::Migration[5.2]
  def change
    add_column :bulk_imports, :kind, :integer
  end
end
