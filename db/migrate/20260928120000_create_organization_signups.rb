class CreateOrganizationSignups < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_signups do |t|
      t.string :id_token, null: false
      t.string :email
      t.string :name
      t.integer :kind
      t.string :website
      t.string :phone
      t.boolean :publicly_visible, default: true, null: false
      t.jsonb :address, default: {}, null: false
      t.boolean :likely_spam, default: false, null: false
      t.string :email_confirmation_token
      t.datetime :email_confirmation_sent_at
      t.datetime :email_confirmed_at
      t.datetime :details_completed_at
      t.references :creator, index: true
      t.references :organization, index: true

      t.timestamps
    end
    add_index :organization_signups, :id_token, unique: true
  end
end
