class RemoveHasBikeSearchFromOrganization < ActiveRecord::Migration[4.2]
  def change
    remove_column :organizations, :has_bike_search, :boolean
  end
end
