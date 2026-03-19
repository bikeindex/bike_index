class ReplaceBikeOrganizationIdWithBikeIdAndOrganizationIdOnBikeOrganizationNotes < ActiveRecord::Migration[8.1]
  def up
    add_reference :bike_organization_notes, :bike, null: false, foreign_key: false
    add_reference :bike_organization_notes, :organization, null: false, foreign_key: false

    remove_index :bike_organization_notes, :bike_organization_id
    remove_column :bike_organization_notes, :bike_organization_id

    add_index :bike_organization_notes, [:bike_id, :organization_id], unique: true
  end

  def down
    remove_index :bike_organization_notes, [:bike_id, :organization_id]

    add_reference :bike_organization_notes, :bike_organization, null: false, foreign_key: false, index: {unique: true}

    remove_reference :bike_organization_notes, :bike
    remove_reference :bike_organization_notes, :organization
  end
end
