class AddCreationOrganizationToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :creation_organization_id, :integer
  end
end
