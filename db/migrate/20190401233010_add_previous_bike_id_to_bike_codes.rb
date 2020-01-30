class AddPreviousBikeIdToBikeCodes < ActiveRecord::Migration[4.2]
  def change
    add_column :bike_codes, :previous_bike_id, :integer
  end
end
