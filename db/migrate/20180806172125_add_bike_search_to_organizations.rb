class AddBikeSearchToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :has_bike_search, :boolean, default: false, null: false
  end
end
