class AddApprovedToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :approved_stolen, :boolean
  end
end
