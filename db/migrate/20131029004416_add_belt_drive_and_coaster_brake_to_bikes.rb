class AddBeltDriveAndCoasterBrakeToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :belt_drive, :boolean, default: false
    add_column :bikes, :coaster_brake, :boolean, default: false
  end
end
