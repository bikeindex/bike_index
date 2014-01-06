class AddRecoveredBikeToBikeAttributes < ActiveRecord::Migration
  def change
    add_column :bikes, :recovered, :boolean, default: false, null: false
  end
end
