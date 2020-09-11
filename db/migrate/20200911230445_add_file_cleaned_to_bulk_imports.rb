class AddFileCleanedToBulkImports < ActiveRecord::Migration[5.2]
  def change
    add_column :bulk_imports, :file_cleaned, :boolean, default: false
  end
end
