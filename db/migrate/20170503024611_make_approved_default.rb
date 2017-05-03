class MakeApprovedDefault < ActiveRecord::Migration
  def change
    change_column :organizations, :approved, :boolean, default: true, null: true
  end
end
