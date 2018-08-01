class RemoveOrganizationDeals < ActiveRecord::Migration
  def change
    drop_table :organization_deals
  end
end
