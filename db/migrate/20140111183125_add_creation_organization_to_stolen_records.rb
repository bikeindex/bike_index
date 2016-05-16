class AddCreationOrganizationToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolenRecords, :creation_organization_id, :integer
  end
end
