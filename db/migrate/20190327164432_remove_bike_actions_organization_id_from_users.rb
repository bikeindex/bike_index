class RemoveBikeActionsOrganizationIdFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :bike_actions_organization_id, :integer
  end
end
