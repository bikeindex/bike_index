class AddErrorsToBParams < ActiveRecord::Migration
  def change
    add_column :bikeParams, :bike_errors, :text
  end
end
