class CreateOrganizationDeals < ActiveRecord::Migration
  def change
    create_table :organization_deals do |t|
      t.integer :organization_id
      t.string :deal_name 
      t.string :email
      t.string :user_id
      
      t.timestamps
    end
  end
end
