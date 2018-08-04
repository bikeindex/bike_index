class AddOrganizationWithBikeActionsId < ActiveRecord::Migration
  def change
    add_reference :users, :bike_actions_organization, index: true 
  end
end
