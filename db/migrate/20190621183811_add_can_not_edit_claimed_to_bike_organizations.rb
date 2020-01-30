class AddCanNotEditClaimedToBikeOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :bike_organizations, :can_not_edit_claimed, :boolean, default: false, null: false
  end
end
