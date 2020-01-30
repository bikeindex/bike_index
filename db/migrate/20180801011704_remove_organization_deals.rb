class RemoveOrganizationDeals < ActiveRecord::Migration[4.2]
  def change
    drop_table :organization_deals
  end
end
