class AddOrganizationWithBikeActionsId < ActiveRecord::Migration[4.2]
  def change
    add_reference :users, :bike_actions_organization, index: true
  end
end
