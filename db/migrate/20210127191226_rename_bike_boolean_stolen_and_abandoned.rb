class RenameBikeBooleanStolenAndAbandoned < ActiveRecord::Migration[5.2]
  def change
    rename_column :bikes, :stolen, :is_stolen
    rename_column :bikes, :abandoned, :is_abandoned
    # Also, handle statuses for external registry bikes
    rename_column :external_registry_bikes, :status, :old_status
    add_column :external_registry_bikes, :status, :integer
    # Remove this column, it's unused and unnecessary
    remove_column :stolen_records, :time
  end
end
