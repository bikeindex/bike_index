class AddNotesToBikeOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :bike_organizations, :notes, :text
  end
end
