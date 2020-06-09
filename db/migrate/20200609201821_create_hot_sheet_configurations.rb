class CreateHotSheetConfigurations < ActiveRecord::Migration[5.2]
  def change
    create_table :hot_sheet_configurations do |t|
      t.references :organization
      t.integer :send_seconds_past_midnight
      t.string :timezone_str
      t.integer :search_radius_miles
      t.boolean :enabled, default: false

      t.timestamps
    end
  end
end
