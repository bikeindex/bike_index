class RenameIsEnabledOnHotSheetConfigurations < ActiveRecord::Migration[5.2]
  def change
    rename_column :hot_sheet_configurations, :is_enabled, :is_on
    reversible do |mig|
      mig.up do
        change_column :hot_sheet_configurations, :search_radius_miles, :float
      end
      mig.down do
        change_column :hot_sheet_configurations, :search_radius_miles, :integer
      end
    end
  end
end
