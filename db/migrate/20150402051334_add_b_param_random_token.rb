class AddBParamRandomToken < ActiveRecord::Migration
  def change
    add_column :bikeParams, :id_token, :text
  end
end
