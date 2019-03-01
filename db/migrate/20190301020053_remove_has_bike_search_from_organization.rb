class RemoveHasBikeSearchFromOrganization < ActiveRecord::Migration
  def change
    remove_column :organizations, :has_bike_search, :boolean
  end
end
