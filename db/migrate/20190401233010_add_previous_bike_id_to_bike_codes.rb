class AddPreviousBikeIdToBikeCodes < ActiveRecord::Migration
  def change
    add_column :bike_codes, :previous_bike_id, :integer
  end
end
