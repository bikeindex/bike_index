class AddCreationStateAttributesAndRemoveUnusedBikeAttributes < ActiveRecord::Migration
  def change
    # Associate bikes with creation state
    add_reference :bikes, :creation_state, index: true
    # Associate creator in creation states 
    add_column :creation_states, :creator_id, :integer
    add_index :creation_states, :creator_id
    # Just remove these, we aren't using them
    remove_column :bikes, :location_id, :string
    remove_column :bikes, :creation_zipcode, :string
    remove_column :bikes, :creation_country_id, :string
    remove_column :bikes, :cached_attributes, :string
  end
end
