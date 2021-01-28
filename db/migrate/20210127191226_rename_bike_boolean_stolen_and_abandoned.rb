class RenameBikeBooleanStolenAndAbandoned < ActiveRecord::Migration[5.2]
  def change
    rename_column :bikes, :stolen, :is_stolen
    rename_column :bikes, :abandoned, :is_abandoned
    remove_column :stolen_records, :time
  end
end
