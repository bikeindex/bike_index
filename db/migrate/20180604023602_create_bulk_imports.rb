class CreateBulkImports < ActiveRecord::Migration
  def change
    create_table :bulk_imports do |t|
      t.references :organization
      t.references :user
      t.text :file_url
      t.integer :bikes_imported
      t.json :import_errors, default: {}

      t.timestamps null: false
    end
  end
end
