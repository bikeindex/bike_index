class AddIndicesToTables < ActiveRecord::Migration
  def change
    add_index :bikes, :primary_frame_color_id
    add_index :bikes, :secondary_frame_color_id
    add_index :bikes, :tertiary_frame_color_id
    add_index :bikes, :manufacturer_id
    add_index :bikes, :current_stolenRecord_id
    add_index :bikes, :cycle_type_id
    add_index :bikes, :cardId
    add_index :bikes, :paint_id
    add_index :components, :bike_id
    add_index :components, :manufacturer_id
    add_index :normalized_serial_segments, :bike_id
    add_index :integrations, :user_id
    add_index :organizationInvitations, :organization_id
    add_index :states, :country_id
    add_index :stolenRecords, :bike_id
    add_index :ownerships, :bike_id
    add_index :ownerships, :user_id
    add_index :ownerships, :creator_id
  end
end
