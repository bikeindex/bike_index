class CreateOrganizationMessages < ActiveRecord::Migration
  def change
    create_table :organization_messages do |t|
      t.integer :kind, default: 0, null: 0
      t.references :organization, index: true
      t.references :sender, index: true
      t.references :bike, index: true
      t.string :email
      t.text :body
      t.string :delivery_status
      t.string :address
      t.float :latitude
      t.float :longitude
      t.float :accuracy

      t.timestamps null: false
    end
  end
end
