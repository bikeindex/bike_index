class CreateOrganizationDeals < ActiveRecord::Migration
  def change
    create_table :organizationDeals do |t|
      t.integer :organization_id
      t.string :deal_name 
      t.string :email
      t.string :user_id
      
      t.timestamps
    end
  end
end
