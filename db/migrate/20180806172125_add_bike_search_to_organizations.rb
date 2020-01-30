class AddBikeSearchToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :has_bike_search, :boolean, default: false, null: false
  end
end
