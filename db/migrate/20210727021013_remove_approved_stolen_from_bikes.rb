class RemoveApprovedStolenFromBikes < ActiveRecord::Migration[5.2]
  def change
    remove_column :bikes, :approved_stolen, :boolean
  end
end
