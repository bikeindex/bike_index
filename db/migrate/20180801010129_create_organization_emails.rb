class CreateOrganizationEmails < ActiveRecord::Migration
  def change
    create_table :organization_emails do |t|
      t.integer :kind, default: 0, null: 0
      t.references :organization, index: true
      t.references :sender, index: true
      t.references :bike, index: true
      t.string :email
      t.text :body
      t.string :location_name
      t.float :latitude
      t.float :longitude

      t.timestamps null: false
    end
  end
end
