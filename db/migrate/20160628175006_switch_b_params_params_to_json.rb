class SwitchBParamsParamsToJson < ActiveRecord::Migration
  def up
    rename_column :b_params, :params, :old_params
    add_column :b_params, :params, :json, default: { bike: { } }.to_json, null: { bike: { } }.to_json
  end

  def down
    remove_column :b_params, :params
    rename_column :b_params, :old_params, :params
  end
end
