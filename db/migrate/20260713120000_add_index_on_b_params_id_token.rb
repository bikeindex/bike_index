class AddIndexOnBParamsIdToken < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :b_params, :id_token, algorithm: :concurrently
  end
end
