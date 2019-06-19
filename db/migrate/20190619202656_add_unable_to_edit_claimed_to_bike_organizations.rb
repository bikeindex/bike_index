class AddUnableToEditClaimedToBikeOrganizations < ActiveRecord::Migration
  def change
    add_column :bike_organizations, :unable_to_edit_claimed, :boolean, default: false, null: false
  end
end
