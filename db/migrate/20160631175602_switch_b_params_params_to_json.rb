class SwitchBParamsParamsToJson < ActiveRecord::Migration
  def change
    rename_column :b_params, :params, :old_params
    add_column :b_params, :params, :json, default: { bike: { } }, null: { bike: { } }
  end
end
