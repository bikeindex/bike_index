class RemoveBikebookModelsVariants < ActiveRecord::Migration[8.1]
  def change
    remove_column :bikebook_models, :variants, :jsonb, default: [], null: false
  end
end
