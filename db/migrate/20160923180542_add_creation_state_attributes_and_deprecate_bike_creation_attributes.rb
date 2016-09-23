class AddCreationStateAttributesAndDeprecateBikeCreationAttributes < ActiveRecord::Migration
  def change
    # Associate bikes with creation state
    add_reference :bikes, :creation_state, index: true
    # Associate creator in creation states 
    add_column :creation_states, :creator_id, :integer
    add_index :creation_states, :creator_id
    # Deprecate bike creation attributes
    rename_column :creation_states, :bike_id, :deprecated_bike_id
    rename_column :bikes, :creation_organization_id, :deprecated_creation_organization_id
    rename_column :bikes, :creator_id, :deprecated_creator_id
    rename_column :bikes, :registered_new, :deprecated_registered_new
    # Just remove these, we aren't using them
    rename_column :bikes, :location_id, :deprecated_location_id
    remove_column :bikes, :creation_zipcode, :string
    remove_column :bikes, :creation_country_id, :string
    remove_column :bikes, :cached_attributes, :string
  end
end
