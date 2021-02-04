class CreateImpoundConfigurations < ActiveRecord::Migration[5.2]
  def change
    create_table :impound_configurations do |t|
      t.references :organization
      t.boolean :public_view, default: false
      t.boolean :bulk_import_view, default: false

      t.integer :display_id_next_integer
      t.string :display_id_prefix

      t.timestamps
    end

    rename_column :impound_records, :display_id, :display_id_integer
    add_column :impound_records, :display_id, :string
    add_column :impound_records, :display_id_prefix, :string
  end
end
