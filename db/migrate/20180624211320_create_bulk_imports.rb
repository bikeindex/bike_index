class CreateBulkImports < ActiveRecord::Migration
  def change
    create_table :bulk_imports do |t|
      t.references :organization
      t.references :user
      t.text :file
      t.integer :progress, default: 0
      t.boolean :no_notify, default: false
      t.json :import_errors, default: {}

      t.timestamps null: false
    end
  end
end
