class RemoveNotesFromBikeOrganizations < ActiveRecord::Migration[8.1]
  def change
    remove_column :bike_organizations, :notes, :text
  end
end
