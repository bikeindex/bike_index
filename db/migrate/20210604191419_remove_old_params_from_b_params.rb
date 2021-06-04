class RemoveOldParamsFromBParams < ActiveRecord::Migration[5.2]
  def change
    remove_column :b_params, :old_params, :text
  end
end
