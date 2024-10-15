class RenameBParamsParamsJsonb < ActiveRecord::Migration[6.1]
  def change
    remove_column :b_params, :params, :json
    rename_column :b_params, :params_jsonb, :params
  end
end
