class CreateBikebookModels < ActiveRecord::Migration[8.1]
  def change
    create_table :bikebook_models do |t|
      t.string :catalog_id, null: false
      t.string :manufacturer_slug, null: false
      t.string :name, null: false
      t.string :model_slug, null: false
      t.integer :first_year, null: false
      t.integer :final_year
      t.string :markets, array: true, default: [], null: false
      t.jsonb :variants, default: [], null: false

      t.timestamps
    end
    add_index :bikebook_models, :catalog_id, unique: true
    add_index :bikebook_models, %i[manufacturer_slug model_slug]
  end
end
