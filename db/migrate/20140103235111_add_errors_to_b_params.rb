class AddErrorsToBParams < ActiveRecord::Migration
  def change
    add_column :b_params, :bike_errors, :text
  end
end
