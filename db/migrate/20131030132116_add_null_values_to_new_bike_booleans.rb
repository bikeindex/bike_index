class AddNullValuesToNewBikeBooleans < ActiveRecord::Migration
  def change
    change_column_null :bikes, :belt_drive, false
    change_column_null :bikes, :coaster_brake, false
  end
end
