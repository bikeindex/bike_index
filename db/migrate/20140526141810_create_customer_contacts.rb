class CreateCustomerContacts < ActiveRecord::Migration
  def change
    create_table :customer_contacts do |t|
      t.integer :user_id
      t.string :user_email
      t.integer :creator_id
      t.string :creator_email
      t.string :title
      t.string :contact_type
      t.text :body
      t.integer :bike_id

      t.timestamps
    end
  end
end
