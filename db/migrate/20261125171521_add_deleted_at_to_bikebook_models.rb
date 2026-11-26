class AddDeletedAtToBikebookModels < ActiveRecord::Migration[8.1]
  def change
    add_column :bikebook_models, :deleted_at, :datetime
  end
end
