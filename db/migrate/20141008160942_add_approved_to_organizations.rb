class AddApprovedToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :approved, :boolean, default: false, null: false
  end
end
