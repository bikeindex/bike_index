class RenameBikeSoonCurrentOwnership < ActiveRecord::Migration[5.2]
  def change
    rename_column :bikes, :soon_current_ownership_id, :current_ownership_id
  end
end
