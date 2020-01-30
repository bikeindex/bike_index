class RemoveBikeActionsOrganizationIdFromUsers < ActiveRecord::Migration[4.2]
  def change
    remove_column :users, :bike_actions_organization_id, :integer
  end
end
