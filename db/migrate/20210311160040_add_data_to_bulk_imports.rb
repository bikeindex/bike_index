class AddDataToBulkImports < ActiveRecord::Migration[5.2]
  def change
    add_column :bulk_imports, :data, :jsonb
  end
end
