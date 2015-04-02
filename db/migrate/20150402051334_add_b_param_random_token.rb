class AddBParamRandomToken < ActiveRecord::Migration
  def change
    add_column :b_params, :id_token, :text
  end
end
