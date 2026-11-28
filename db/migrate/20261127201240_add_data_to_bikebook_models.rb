class AddDataToBikebookModels < ActiveRecord::Migration[8.1]
  def change
    add_column :bikebook_models, :data, :jsonb
    add_column :bikebook_models, :data_file, :string
  end
end
