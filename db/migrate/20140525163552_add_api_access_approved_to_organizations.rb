class AddApiAccessApprovedToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :api_access_approved, :boolean, default: false, null: false
  end
end
