class AddDeletedAtToBikeOrganizations < ActiveRecord::Migration
  def change
    add_column :bike_organizations, :deleted_at, :datetime
    add_index :bike_organizations, :deleted_at
  end
end
