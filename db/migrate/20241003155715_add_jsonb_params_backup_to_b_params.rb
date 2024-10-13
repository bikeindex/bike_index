class AddJsonbParamsBackupToBParams < ActiveRecord::Migration[6.1]
  def change
    add_column :b_params, :params_jsonb, :jsonb
  end
end
