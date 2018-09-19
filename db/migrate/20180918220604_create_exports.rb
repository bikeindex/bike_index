class CreateExports < ActiveRecord::Migration
  def change
    create_table :exports do |t|
      t.references :organization, index: true
      t.text :file
      t.integer :kind, default: 0
      t.integer :progress, default: 0
      t.integer :rows, default: 0
      t.jsonb :options, default: {}

      t.timestamps null: false
    end
  end
end
