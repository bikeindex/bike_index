class CreateExports < ActiveRecord::Migration
  def change
    create_table :exports do |t|
      t.references :organization, index: true
      t.references :user, index: true
      t.text :file
      t.integer :file_format, default: 0
      t.integer :kind, default: 0
      t.integer :progress, default: 0
      t.integer :rows
      t.jsonb :options, default: {}

      t.timestamps null: false
    end
  end
end
