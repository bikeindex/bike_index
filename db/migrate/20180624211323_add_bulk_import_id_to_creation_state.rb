class AddBulkImportIdToCreationState < ActiveRecord::Migration
  def change
    add_column :creation_states, :bulk_import_id, :integer
  end
end
