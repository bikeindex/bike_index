class ReplaceBikebookModelsVariants < ActiveRecord::Migration[8.1]
  def change
    remove_column :bikebook_models, :variants, :jsonb, default: [], null: false
    add_column :bikebook_models, :market_variants, :string, array: true, default: [], null: false
  end
end
