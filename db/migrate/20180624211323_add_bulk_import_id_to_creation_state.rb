class AddBulkImportIdToCreationState < ActiveRecord::Migration[4.2]
  def change
    add_column :creation_states, :bulk_import_id, :integer
  end
end
